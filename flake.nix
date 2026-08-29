{
  description = "Development environment for the text adventure";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          ghcWithDependencies = pkgs.haskellPackages.ghcWithPackages (
            haskellPackages: with haskellPackages; [
              esqueleto
              persistent
              persistent-sqlite
              temporary
            ]
          );
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cabal-install
              fourmolu
              ghcWithDependencies
              go-task
              haskell-language-server
              hlint
              pkg-config
              sqlite
              zlib
            ];
          };
        }
      );
    };
}
