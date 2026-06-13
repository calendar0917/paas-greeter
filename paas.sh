#! /usr/bin/env bash
set -euo pipefail # 严格模式
cmd="${1:-}"      # 解析第一个参数
shift || true     # 去除第一个参数

parse_deploy_args() {
  repo=""
  name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --name)
      name="$2"
      shift 2
      ;;
    *)
      echo "unknown option $1" >&2
      exit 1
      ;;
    esac
  done
  if [[ -z "$repo" || -z "$name" ]]; then
    echo "error: should provide repo and name" >&2
    exit 1
  fi
}

case "$cmd" in
deploy)
  # deploy --repo ... --name ...
  parse_deploy_args "$@"
  echo "repo=$repo,name=$name"
  # 创建 repo
  repo_dir="/var/lib/paas/repos/$name"
  rootfs_dir="/var/lib/paas/rootfs/$name"
  sudo mkdir -p /var/lib/paas/repos /var/lib/paas/rootfs
  rm -rf "$repo_dir"
  git clone "$repo" "$repo_dir"

  # 构建
  cd "$repo_dir"
  rm -f result # 清除旧 result 链接
  /nix/var/nix/profiles/default/bin/nix build
  store_path=$(realpath result)

  # 将 result 链接到仓库
  sudo rm -rf "$rootfs_dir"
  sudo mkdir -p "$rootfs_dir"
  for p in $(/nix/var/nix/profiles/default/bin/nix-store -qR "$store_path"); do
    dest="$rootfs_dir$p" # 例如 /var/lib/paas/rootfs/greeter/nix/store/xxx
    sudo mkdir -p "$(dirname "$dest")"
    sudo cp -a "$p" "$dest"
  done

  # 创建软链接
  binary_in_host="$store_path/bin/$name"
  if [[ ! -x "$binary_in_host" ]]; then
    echo "错误: 在 $binary_in_host 找不到可执行文件" >&2
    exit 1
  fi
  # 容器内的 /bin 目录
  container_bin="$rootfs_dir/bin"
  sudo mkdir -p "$container_bin"
  # 创建软链接，链接到容器内的绝对路径（注意是 $store_path/bin/$name，而不是宿主机的路径）
  sudo ln -sf "$store_path/bin/$name" "$container_bin/$name"

  # 重启 systemd 服务
  sudo systemctl daemon-reload # 确保 systemd 看到新的服务文件
  sudo systemctl restart "paas@$name"
  ;;
status)
  # status name
  name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "usage: paas status <name>" >&2
    exit 1
  fi
  sudo systemctl status "paas@$name"
  ;;
logs)
  # logs name
  name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "usage: paas logs <name>" >&2
    exit 1
  fi
  sudo journalctl -u "paas@$name" -f
  ;;
stop)
  # stop name
  name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "usage: paas stop <name>" >&2
    exit 1
  fi
  sudo systemctl stop "paas@$name"
  ;;
start)
  # start name
  name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "usage: paas start <name>" >&2
    exit 1
  fi
  sudo systemctl start "paas@$name"
  ;;
esac
