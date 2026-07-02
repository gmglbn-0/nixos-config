{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixos-autoupdate;

  # ── Script ────────────────────────────────────────────────────────────────
  # Nodes is a list of { name, host, arch } attrsets, serialised for bash.
  nodesBash = lib.concatMapStringsSep "\n" (n: ''
    NODES+=("${n.name}")
    HOSTS["${n.name}"]="${n.host}"
  '') cfg.nodes;

  script = pkgs.writeShellApplication {
    name = "nixos-autoupdate";
    runtimeInputs = with pkgs; [ git nix nixos-rebuild curl jq coreutils gnugrep openssh ];
    text = ''
      set -euo pipefail

      # ── Load Telegram credentials ─────────────────────────────────────────
      # shellcheck source=/dev/null
      source "${cfg.telegramCredentialsFile}"
      : "''${BOT_TOKEN:?BOT_TOKEN missing from credentials file}"
      : "''${CHAT_ID:?CHAT_ID missing from credentials file}"

      API="https://api.telegram.org/bot$BOT_TOKEN"

      # ── Node list ─────────────────────────────────────────────────────────
      declare -a NODES=()
      declare -A HOSTS=()
      ${nodesBash}

      # ── Helpers ───────────────────────────────────────────────────────────
      tg_send() {
        local text="$1" extra="''${2:-}"
        curl -sf -X POST "$API/sendMessage" \
          -H "Content-Type: application/json" \
          -d "$(jq -n \
            --arg chat_id  "$CHAT_ID" \
            --arg text     "$text" \
            --argjson extra "''${extra:-null}" \
            'if $extra != null then {chat_id: $chat_id, text: $text, parse_mode: "HTML"} + $extra
             else {chat_id: $chat_id, text: $text, parse_mode: "HTML"} end')" \
        > /dev/null
      }

      tg_answer_callback() {
        local callback_id="$1" text="''${2:-}"
        curl -sf -X POST "$API/answerCallbackQuery" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg id "$callback_id" --arg text "$text" \
            '{callback_query_id: $id, text: $text}')" \
        > /dev/null || true
      }

      # ── Stage 1: Update flake ─────────────────────────────────────────────
      echo "[autoupdate] Pulling latest commits..."
      cd "${cfg.flakeDir}"
      git pull --ff-only

      echo "[autoupdate] Updating flake inputs..."
      nix flake update 2>&1 | tee /tmp/nixos-autoupdate-flake-update.log

      # ── Stage 2: Pre-build all nodes ──────────────────────────────────────
      declare -A NEW_CLOSURES=()
      declare -A BUILD_LOGS=()

      for node in "''${NODES[@]}"; do
        echo "[autoupdate] Building $node..."
        log_file="/tmp/nixos-autoupdate-build-$node.log"

        set +e
        closure=$(nix build \
          "${cfg.flakeDir}#nixosConfigurations.$node.config.system.build.toplevel" \
          --no-link --print-out-paths 2>"$log_file")
        build_exit=$?
        set -e

        if [ "$build_exit" -eq 0 ] && [ -n "$closure" ]; then
          NEW_CLOSURES["$node"]="$closure"
          echo "[autoupdate] $node built → $closure"
        else
          BUILD_LOGS["$node"]="FAILED"
          echo "[autoupdate] $node build FAILED (see $log_file)"
        fi
      done

      # ── Stage 3: Compute diffs & send Telegram messages ───────────────────

      for node in "''${NODES[@]}"; do
        if [ "''${BUILD_LOGS[$node]:-}" = "FAILED" ]; then
          tg_send "❌ <b>nixos-autoupdate — $node</b>
      Build failed. Check rei: <code>journalctl -u nixos-autoupdate</code>"
          continue
        fi

        closure="''${NEW_CLOSURES[$node]}"

        # Compute package diff vs currently-running closure
        current_sys="/run/current-system"
        if [ "$node" = "${cfg.selfNode}" ]; then
          diff_output=$(nix store diff-closures "$current_sys" "$closure" 2>/dev/null \
            | grep -E '^[A-Za-z]' | head -20 || echo "(diff unavailable)")
        else
          diff_output="(diff shown for rei only; remote node diff requires switch)"
        fi

        # Truncate to stay within Telegram's 4096-char limit
        diff_trimmed=$(echo "$diff_output" | head -15)
        if [ "$(echo "$diff_output" | wc -l)" -gt 15 ]; then
          diff_trimmed="$diff_trimmed
      … (truncated)"
        fi

        keyboard=$(jq -n \
          --arg node "$node" \
          '{inline_keyboard: [[
            {text: "✅ Switch", callback_data: ("switch_" + $node)},
            {text: "❌ Skip",   callback_data: ("skip_"   + $node)}
          ]]}')

        # Send query message
        curl -sf -X POST "$API/sendMessage" \
          -H "Content-Type: application/json" \
          -d "$(jq -n \
            --arg chat_id  "$CHAT_ID" \
            --arg node     "$node" \
            --arg diff     "$diff_trimmed" \
            --argjson kb   "$keyboard" \
            '{
              chat_id: $chat_id,
              parse_mode: "HTML",
              text: ("🔄 <b>nixos-autoupdate — " + $node + "</b>\n\nPackage changes:\n<pre>" + $diff + "</pre>\n\nSwitch this node to the new configuration?"),
              reply_markup: $kb
            }')" > /dev/null
      done

      # ── Stage 4: Poll for responses until next calendar event ─────────────
      # Timer fires at 05:00 daily → wait up to 23h for replies (covers ~12:00)
      DEADLINE=$(( $(date +%s) + 23 * 3600 ))
      LAST_UPDATE_ID=0
      declare -A RESOLVED=()

      echo "[autoupdate] Polling for Telegram responses (deadline in 23h)..."

      while [ "$(date +%s)" -lt "$DEADLINE" ]; do
        # Mark all failed nodes as resolved so we don't wait for them
        for node in "''${NODES[@]}"; do
          if [ "''${BUILD_LOGS[$node]:-}" = "FAILED" ]; then
            RESOLVED["$node"]=1
          fi
        done

        # Check if all nodes resolved
        all_done=true
        for node in "''${NODES[@]}"; do
          if [ -z "''${RESOLVED[$node]:-}" ]; then
            all_done=false
            break
          fi
        done
        "$all_done" && break

        # Fetch updates (POST with JSON body so allowed_updates is properly serialised)
        updates=$(curl -sf -X POST "$API/getUpdates" \
          -H "Content-Type: application/json" \
          -d "$(jq -n \
            --argjson offset "$(( LAST_UPDATE_ID + 1 ))" \
            --argjson timeout 30 \
            '{offset: $offset, timeout: $timeout, allowed_updates: ["callback_query"]}')" \
          || echo '{"result":[]}')

        while IFS= read -r update; do
          update_id=$(echo "$update" | jq -r '.update_id // empty')
          [ -z "$update_id" ] && continue
          [ "$update_id" -le "$LAST_UPDATE_ID" ] && continue
          LAST_UPDATE_ID="$update_id"

          callback_id=$(echo "$update" | jq -r '.callback_query.id // empty')
          cb_data=$(echo "$update"     | jq -r '.callback_query.data // empty')
          [ -z "$cb_data" ] && continue

          action=$(echo "$cb_data" | cut -d_ -f1)
          node=$(echo "$cb_data"   | cut -d_ -f2-)

          # Validate node name
          valid_node=false
          for n in "''${NODES[@]}"; do
            [ "$n" = "$node" ] && valid_node=true && break
          done
          "$valid_node" || continue

          [ -n "''${RESOLVED[$node]:-}" ] && {
            tg_answer_callback "$callback_id" "Already handled"
            continue
          }

          tg_answer_callback "$callback_id" "Processing..."

          if [ "$action" = "switch" ]; then
            host="''${HOSTS[$node]}"
            echo "[autoupdate] Switching $node (host=$host)..."

            set +e
            if [ "$node" = "${cfg.selfNode}" ]; then
              nixos-rebuild switch --flake "${cfg.flakeDir}#$node" 2>&1 \
                | tee "/tmp/nixos-autoupdate-switch-$node.log"
              sw_exit=$?
            else
              nixos-rebuild switch \
                --flake "${cfg.flakeDir}#$node" \
                --target-host "$host" \
                --sudo 2>&1 \
                | tee "/tmp/nixos-autoupdate-switch-$node.log"
              sw_exit=$?
            fi
            set -e

            if [ "$sw_exit" -eq 0 ]; then
              tg_send "✅ <b>$node</b> switched successfully!"
            else
              tail_log=$(tail -20 "/tmp/nixos-autoupdate-switch-$node.log" | sed 's/</\&lt;/g; s/>/\&gt;/g')
              tg_send "❌ <b>$node</b> switch failed!
      <pre>$tail_log</pre>"
            fi
            RESOLVED["$node"]=1

          elif [ "$action" = "skip" ]; then
            tg_send "⏭ <b>$node</b> skipped."
            RESOLVED["$node"]=1
          fi

        done < <(echo "$updates" | jq -c '.result[]? // empty')


      done

      # Notify about any nodes left unresolved at deadline
      for node in "''${NODES[@]}"; do
        if [ -z "''${RESOLVED[$node]:-}" ]; then
          tg_send "⏰ <b>$node</b> — no response received before deadline. Skipped."
        fi
      done

      echo "[autoupdate] Done."
    '';
  };

in
{
  # ── Options ───────────────────────────────────────────────────────────────
  options.services.nixos-autoupdate = {
    enable = lib.mkEnableOption "nightly NixOS flake auto-update with Telegram approval";

    flakeDir = lib.mkOption {
      type    = lib.types.path;
      default = "/home/gmglbn_0/git/nixos-config";
      description = "Absolute path to the nixos-config flake repository on rei.";
    };

    selfNode = lib.mkOption {
      type    = lib.types.str;
      default = "rei";
      description = "Name of this node (used to switch locally instead of via SSH).";
    };

    nodes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; description = "Flake output name."; };
          host = lib.mkOption { type = lib.types.str; description = "SSH hostname or IP."; };
        };
      });
      default = [];
      description = "Nodes to build and offer for switching.";
    };

    telegramCredentialsFile = lib.mkOption {
      type    = lib.types.path;
      default = "/etc/nixos-updater/telegram.env";
      description = ''
        Path to a file containing:
          BOT_TOKEN=<token>
          CHAT_ID=<chat-id>
        This file must be readable by root and should NOT be in the Nix store.
      '';
    };

    calendar = lib.mkOption {
      type    = lib.types.str;
      default = "05:00";
      description = "systemd OnCalendar expression for when to run.";
    };
  };

  # ── Implementation ────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    # x86_64 cross-build support via binfmt (needed for loona/akira/latte)
    boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

    # Ensure nixos-rebuild is available to root at runtime
    environment.systemPackages = [ pkgs.nixos-rebuild ];

    # Create the credentials directory with tight permissions
    systemd.tmpfiles.rules = [
      "d /etc/nixos-updater 0700 root root -"
    ];

    systemd.services.nixos-autoupdate = {
      description = "Nightly NixOS flake update + Telegram approval";
      wants       = [ "network-online.target" ];
      after       = [ "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        ExecStart       = "${script}/bin/nixos-autoupdate";
        User            = "root";
        # Give enough time: build + 23h poll window
        TimeoutStartSec = "86400";  # 24 h hard cap
        StandardOutput  = "journal";
        StandardError   = "journal";
        # Keep the nix store path accessible
        Environment     = "HOME=/root";
      };
    };

    systemd.timers.nixos-autoupdate = {
      wantedBy    = [ "timers.target" ];
      description = "Nightly NixOS flake auto-update timer";
      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;   # catch up if rei was offline at 05:00
        Unit       = "nixos-autoupdate.service";
      };
    };
  };
}
