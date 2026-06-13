{
    description = "build greeter mod";
    inputs = {
        nixpkgs.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-unstable/nixexprs.tar.xz";
      };
    nixConfig = {
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
      "https://cache.nixos.org"
    ];
  };
    outputs = { self,nixpkgs}:
      let allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
        # 辅助函数，适配所有系统的 nixpkgs
        forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
      in
      {
          packages = forAllSystems({pkgs}:
            let 
              buildGoModule = pkgs.buildGoModule;
            in
            {
                default = buildGoModule {
                    pname = "greeter";
                    version = "0.0.1";
                    src = ./.;
                    vendorHash = null;
                    doCheck = false;
                  };
              }
            );
        };
}
