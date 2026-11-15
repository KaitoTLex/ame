# Hermes Agent for kaitotlex: the Matrix gateway (runs without a login, hence
# linger) and the marine/laplus profiles wired to the local model from llm.nix.
inputs:
{
  pkgs,
  config,
  ...
}:
{
  users.users.kaitotlex.linger = true;

  age.secrets.hermes-matrix-env = {
    file = ../../modules/secrets/hermes-matrix-env.age;
    owner = "kaitotlex";
    group = "users";
    mode = "0400";
  };

  home-manager.users.kaitotlex =
    { lib, ... }:
    let
      localModel = config.services.llama-cpp.settings.alias;
      llamaCppProvider = {
        name = "Local llama.cpp";
        api = "http://127.0.0.1:8080/v1"; # llama-gate
        transport = "chat_completions";
        default_model = localModel;
        models.${localModel} = {
          context_length = config.services.llama-cpp.settings.ctx-size;
          # The GGUF repo ships mmproj-F32.gguf, but the service sets
          # no-mmproj: the projector is not loaded, so there is no vision
          # capability to claim. Saying true here would make Hermes send
          # images the backend cannot decode.
          supports_vision = false;
        };
      };
      # Model wiring for the local-inference profiles. Both are created with
      # `hermes profile create`; only the model block is managed here,
      # deep-merged into each profile's config.yaml the same way the module
      # merges the default one. This is deliberately declarative: a
      # hand-written config.yaml gets silently rewritten by any `hermes model`
      # run (laplus was reverted to anthropic/claude-sonnet-5-5 that way),
      # whereas these values are restored on every rebuild.
      localProfileSettings = {
        model = {
          provider = "custom:llama-cpp-local";
          default = localModel;
        };
        providers.llama-cpp-local = llamaCppProvider;
        # Local 27B generation is single-digit tok/s, so a long report or a
        # multi-file review outlives the 180s default.
        agent.max_turns = null;
        terminal = {
          cwd = "/home/kaitotlex";
          timeout = 3600;
        };
      };
      marineSettings = localProfileSettings;
      laplusSettings = localProfileSettings;
      configMerge = import "${inputs.hermes-agent}/nix/configMergeScript.nix" { inherit pkgs; };
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "senchou" ''exec hermes -p marine "$@"'')
      ];

      home.activation.hermesMarineProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        marine="$HOME/.hermes/profiles/marine"
        if [ -d "$marine" ]; then
          run ${configMerge} ${pkgs.writeText "hermes-marine.json" (builtins.toJSON marineSettings)} "$marine/config.yaml"
        fi
      '';

      home.activation.hermesLaplusProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        laplus="$HOME/.hermes/profiles/laplus"
        if [ -d "$laplus" ]; then
          run ${configMerge} ${pkgs.writeText "hermes-laplus.json" (builtins.toJSON laplusSettings)} "$laplus/config.yaml"
        fi
      '';

      imports = [ inputs.hermes-agent.homeManagerModules.default ];

      programs.hermes-agent.enable = true;
      services.hermes-agent = {
        enable = true;
        gateway.enable = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
        extraDependencyGroups = [
          "anthropic"
          "matrix"
        ];
        environmentFiles = [ config.age.secrets.hermes-matrix-env.path ];
        environment = {
          MATRIX_E2EE_MODE = "required";
          MATRIX_HOMESERVER = "https://matrix.functor.systems";
        };
        settings = {
          model = {
            provider = "anthropic";
            default = "claude-opus-5";
          };
          providers.llama-cpp-local = llamaCppProvider;
          delegation = {
            provider = "custom:llama-cpp-local";
            model = localModel;
            max_concurrent_children = 1;
            fallback_providers = [ ];
          };
          platforms.matrix.enabled = true;
          matrix = {
            allowed_users = [
              "@kaitotlex:matrix.org"
              "@kaitotlex26:functor.systems"
            ];
            require_mention = false;
            process_notices = false;
            session_scope = "room";
            auto_thread = false;
            dm_mention_threads = false;
            max_message_length = 16000;
          };
          group_sessions_per_user = true;
        };
      };
    };
}
