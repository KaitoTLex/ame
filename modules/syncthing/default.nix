#TODO: 
# {
#   config,
#   lib,
#   pkgs,
#   ...
# }:
# let
#   user = "kaito";
#   home = config.users.users.${user}.home;
#   peers = [
#     "kanade"
#     "kuroko"
#   ];
#   photoVersioning = {
#     type = "staggered";
#     params = {
#       cleanInterval = "3600";
#       maxAge = "2592000"; # 30
#     };
#   };
# in
# {
#   age.secrets = {
#     syncthing-cert = {
#       file = ../secrets/syncthing-cert.age;
#       owner = user;
#     };
#     syncthing-key = {
#       file = ../secrets/syncthing-key.age;
#       owner = user;
#     };
#   };
#
#   services.syncthing = {
#     enable = true;
#     inherit user;
#     group = "users";
#     dataDir = home;
#     configDir = "${home}/.config/syncthing";
#     cert = config.age.secrets.syncthing-cert.path;
#     key = config.age.secrets.syncthing-key.path;
#
#     openDefaultPorts = true;
#     overrideDevices = true;
#     overrideFolders = true;
#
#     settings = {
#       options = {
#         urAccepted = -1;
#         globalAnnounceEnabled = false;
#         relaysEnabled = false;
#         localAnnounceEnabled = true;
#       };
#
#       devices = {
#         kanade.id = "";
#         shirakami-fubuki = {
#           id = "";
#           addresses = [ "tcp://" ];
#         };
#       };
#
#       folders = {
#         documents = {
#           id = "documents";
#           path = "${home}/Documents";
#           devices = peers;
#           versioning = photoVersioning;
#         };
#         pictures = {
#           id = "pictures";
#           path = "${home}/Pictures";
#           devices = peers;
#           versioning = photoVersioning;
#         };
#         music = {
#           id = "music";
#           path = "${home}/Music";
#           devices = peers;
#         };
#         videos = {
#           id = "videos";
#           path = "${home}/Videos";
#           devices = peers;
#         };
#       };
#     };
#   };
#
#   boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
# }
