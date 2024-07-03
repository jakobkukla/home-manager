{ config, lib, pkgs, ... }:
let
  cfg = config.programs.goldwarden;

  inherit (lib) concatStringsSep mapAttrsToList escapeShellArg;

  toEnvironmentCfg = vars:
    (concatStringsSep " "
      (mapAttrsToList (k: v: "${k}=${escapeShellArg v}") vars));
in {
  meta.maintainers = with lib.hm.maintainers; [ jakobkukla ];

  options.programs.goldwarden = with lib; {
    enable = mkEnableOption "Goldwarden, a feature-packed Bitwarden compatible desktop client ";

    package = mkOption {
      type = types.package;
      default = pkgs.goldwarden;
      defaultText = literalExpression "pkgs.goldwarden";
      description = ''
        Package providing the {command}`goldwarden` tool.
      '';
    };

    email = mkOption {
      type = types.str;
      example = "name@example.com";
      description = "The email address for your bitwarden account.";
    };

    base_url = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "https://bitwarden.example.com";
      description =
        "The base-url for a self-hosted bitwarden installation.";
    };

    api_url = mkOption {
      type = with types; nullOr str;
      default = "${cfg.base_url}/api";
      example = "https://bitwarden.example.com/api";
      description =
        "The api-url for a self-hosted bitwarden installation.";
    };

    identity_url = mkOption {
      type = with types; nullOr str;
      default = "${cfg.base_url}/identity";
      example = "https://bitwarden.example.com/identity";
      description =
        "The identity-url for a self-hosted bitwarden installation.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # for cli and polkit action
      cfg.package
      # binary exec's into pinentry which should match the DE
      # config.programs.gnupg.agent.pinentryPackage
    ];

    # FIXME: see https://github.com/nix-community/home-manager/blob/59ce796b2563e19821361abbe2067c3bb4143a7d/modules/services/psd.nix#L58
    # for setting path.
    # FIXME: see https://github.com/nix-community/home-manager/blob/59ce796b2563e19821361abbe2067c3bb4143a7d/modules/services/etesync-dav.nix#L42,
    # for configuration with env vars.
    systemd.user.services.goldwarden = {
      Unit = {
        Description = "Goldwarden daemon";
        After = [ "graphical-session.target" ];
      };

      Install.WantedBy = [ "graphical-session.target" ];

      Service = {
        #Environment = [ "PATH=$PATH:${config.programs.gnupg.agent.pinentryPackage}" ];
        Environment =
          toEnvironmentCfg ({
            GOLDWARDEN_API_URI = cfg.api_url;
            GOLDWARDEN_IDENTITY_URI = cfg.identity_url;
            GOLDWARDEN_AUTH_USER = cfg.email;
          });
        ExecStart = "${lib.getExe cfg.package} daemonize";
        Restart = "on-failure";
      };
    };
  };
}
