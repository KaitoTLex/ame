# Shared by both eduroam variants: the agenix-encrypted password and the SJSU
# RADIUS trust anchor (emSign Root CA - G1, extracted from the CAT-generated
# eduroam-linux-SJSU.py installer).
{ ... }:
{
  age.secrets.eduroam.file = ../secrets/eduroam.age;
  environment.etc."eduroam/ca.pem".text = builtins.readFile ./ca.pem;
}
