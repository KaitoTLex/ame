let
  kanade = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLwiBCboUAGMjoNnv1Cr9lO2QSm1/S68vx4VQvCDrKe root@kanade";
in
{
  "eduroam.age".publicKeys = [ kanade ];
}
