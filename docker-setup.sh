#!/bin/bash
#
# 逆向工程Docker准备协议
# ==================================================
# 此脚本为逆向工程任务准备Docker环境。
# 在每次逆向工程会话开始时运行此脚本。
#

set -e

# 输出颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 要预拉取的Docker镜像（按顺序：从最小到最大）
IMAGES=(
    "zricethezav/gitleaks:latest"
    "trufflesecurity/trufflehog:latest"
    "cryptax/android-re:latest"
)

# 函数：打印章节标题
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# 函数：打印状态
print_status() {
    echo -e "[${GREEN}✓${NC}] $1"
}

# 函数：打印警告
print_warning() {
    echo -e "[${YELLOW}⚠${NC}] $1"
}

# 函数：打印错误
print_error() {
    echo -e "[${RED}✗${NC}] $1"
}

#
# 第1步：验证Docker守护进程是否运行
#
print_header "第1步：Docker守护进程状态"

docker info > /dev/null 2>&1
DOCKER_STATUS=$?

if [ $DOCKER_STATUS -ne 0 ]; then
    print_error "Docker守护进程未运行"
    echo ""
    echo "请使用以下方法之一启动Docker："
    echo "  - Docker Desktop：从应用程序打开Docker.app"
    echo "  - Linux：sudo systemctl start docker"
    echo "  - Linux（无root）：dockerd &
    exit 1
fi

DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
print_status "Docker守护进程正在运行"
echo "  版本：$DOCKER_VERSION"

# 检查Docker版本兼容性
REQUIRED_VERSION="20.10"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    print_warning "Docker版本 $DOCKER_VERSION 可能有兼容性问题"
    echo "  推荐：$REQUIRED_VERSION 或更高"
fi

#
# 第2步：预拉取所需镜像
#
print_header "第2步：验证所需镜像"

for IMAGE in "${IMAGES[@]}"; do
    IMAGE_NAME=$(basename "$IMAGE")
    CHECK_CMD="docker images $IMAGE --format '{{.ID}}'"

    if OUTPUT=$($CHECK_CMD 2>/dev/null) && [ -n "$OUTPUT" ]; then
        print_status "$IMAGE_NAME ..... 已缓存"
    else
        echo -n "  正在拉取 $IMAGE_NAME ... "
        if docker pull "$IMAGE" > /dev/null 2>&1; then
            print_status "$IMAGE_NAME ..... 已拉取"
        else
            print_warning "$IMAGE_NAME ..... 失败（继续）"
        fi
    fi
done

#
# 第3步：健康检查 - 验证容器运行时
#
print_header "第3步：容器运行时健康检查"

if docker run --rm zricethezav/gitleaks:latest --version > /dev/null 2>&1; then
    print_status "容器运行时测试 ..... 通过"
else
    print_warning "容器运行时测试 ..... 失败"
    echo "  某些Docker功能可能无法正常工作"
fi

#
# 第4步：显示摘要
#
print_header "Docker准备结果"

# 检查最终状态
ALL_CACHED=true
for IMAGE in "${IMAGES[@]}"; do
    IMAGE_NAME=$(basename "$IMAGE")
    CHECK_CMD="docker images $IMAGE --format '{{.ID}}'"
    if ! OUTPUT=$($CHECK_CMD 2>/dev/null) || [ -z "$OUTPUT" ]; then
        ALL_CACHED=false
        break
    fi
done

if [ "$ALL_CACHED" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  结果：就绪${NC}"
    echo -e "${GREEN}  所有Docker资源均可用${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "开始逆向工程会话..."
    echo ""
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  结果：降级${NC}"
    echo -e "${YELLOW}  某些镜像不可用${NC}"
    echo -e "${YELLOW}  功能集将受到限制${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    exit 1
fi
