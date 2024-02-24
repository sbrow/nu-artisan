{
  description = "Nushell completions for Laravel Artisan commands";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          nushellFull
        ];
      };
    };
}
