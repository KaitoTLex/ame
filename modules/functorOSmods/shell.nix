{ pkgs, lib, ... }:
{
  programs.zsh.enable = true;
  users.users.kaitotlex.shell = lib.mkForce pkgs.zsh;
}
