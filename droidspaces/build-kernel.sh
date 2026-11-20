#!/bin/bash
# Droidspaces kernel build for Xiaomi Mi 6 (sagit), crDroid 14.0 (ba209d35ba7a)
# Works locally and in GitHub Actions (self-hosted or ubuntu runner).
set -e

KDIR="$(cd "$(dirname "$0")/.." && pwd)"   # kernel source root
FRAG="$KDIR/droidspaces/droidspaces.config"

cd "$KDIR"

# Toolchain env (clang 17, like crDroid buildbot)
export PATH=/usr/lib/llvm-17/bin:$PATH
export CC=clang
export LD=aarch64-linux-gnu-ld.bfd
export ARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

JOBS=$(nproc)

# 1. base defconfig
make O=out ARCH=arm64 vendor/xiaomi/mi8998_defconfig -j$JOBS

# 2. merge device fragment (sagit) + droidspaces fragment
KCONFIG_CONFIG=out/.config ./scripts/kconfig/merge_config.sh -m -O out out/.config \
    arch/arm64/configs/vendor/xiaomi/sagit.config \
    "$FRAG"

# 3. resolve new options
make O=out ARCH=arm64 olddefconfig -j$JOBS

# sanity: key options must be =y
# NOTE: CONFIG_CFS_BANDWIDTH impossible on this tree (depends on !SCHED_WALT,
# sagit uses WALT). Droidspaces skips --cpus with a warning; everything else works.
for opt in CONFIG_SYSVIPC CONFIG_POSIX_MQUEUE CONFIG_PID_NS CONFIG_IPC_NS \
           CONFIG_USER_NS CONFIG_DEVTMPFS CONFIG_OVERLAY_FS CONFIG_NET_NS \
           CONFIG_VETH CONFIG_BRIDGE CONFIG_MEMCG CONFIG_CGROUP_PIDS \
           CONFIG_MACVLAN CONFIG_IP6_NF_NAT; do
    grep -q "^$opt=y" out/.config || { echo "MISSING: $opt"; exit 1; }
done
echo "CONFIG CHECK OK"
grep -q "^CONFIG_ANDROID_PARANOID_NETWORK=y" out/.config && { echo "ERROR: paranoid network still on"; exit 1; } || true

# 4. build
make O=out ARCH=arm64 CC=clang LD=aarch64-linux-gnu-ld.bfd -j$JOBS

ls -la out/arch/arm64/boot/Image.gz-dtb
echo "BUILD DONE"
