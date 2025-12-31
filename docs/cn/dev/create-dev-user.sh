#!/bin/bash
# 创建开发用户

echo "=========================================="
echo "  创建开发用户"
echo "=========================================="
echo ""

# 检查是否是 root
if [ "$EUID" -ne 0 ]; then 
    echo "错误：此脚本需要 root 权限运行"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 询问用户名
read -p "请输入新用户名 [默认: developer]: " username
username=${username:-developer}

# 检查用户是否已存在
if id "$username" &>/dev/null; then
    echo "用户 $username 已存在"
    exit 0
fi

# 创建用户
echo "创建用户: $username"
useradd -m -s /bin/bash "$username"

# 设置密码
echo "请为用户 $username 设置密码:"
passwd "$username"

# 添加到 sudo 组
usermod -aG sudo "$username"

# 设置 /data/github 目录权限
if [ -d "/data/github" ]; then
    chown -R $username:$username /data/github
    echo "已设置 /data/github 所有权为 $username"
fi

# 设置 /data/go 目录权限（如果存在）
if [ -d "/data/go" ]; then
    chown -R $username:$username /data/go
    echo "已设置 /data/go 所有权为 $username"
fi

echo ""
echo "=========================================="
echo "用户创建完成！"
echo "=========================================="
echo ""
echo "切换到新用户："
echo "  su - $username"
echo ""
echo "然后运行配置脚本："
echo "  bash /data/github/genai-toolbox/docs/cn/setup-go-data-disk.sh"
echo ""
