#!/usr/bin/env python3
"""
MCP Toolbox Python 客户端示例
使用 BasicAuth 连接到 K8s 部署的 Toolbox 服务

依赖安装:
    pip install toolbox-core python-dotenv
"""

import asyncio
import base64
import os
from typing import Optional
from toolbox_core import ToolboxClient
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()


def create_basic_auth_header(username: str, password: str) -> dict:
    """
    创建 HTTP Basic Auth header
    
    Args:
        username: 用户名
        password: 密码
    
    Returns:
        包含 Authorization header 的字典
    """
    auth_str = f"{username}:{password}"
    auth_bytes = auth_str.encode('ascii')
    auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
    
    return {"Authorization": f"Basic {auth_b64}"}


async def example_1_basic_usage():
    """示例 1: 基本使用"""
    print("\n=== 示例 1: 基本使用 ===")
    
    # 从环境变量读取配置
    toolbox_url = os.getenv("TOOLBOX_URL", "https://toolbox.example.com")
    username = os.getenv("TOOLBOX_USER", "admin")
    password = os.getenv("TOOLBOX_PASSWORD")
    
    if not password:
        raise ValueError("请设置 TOOLBOX_PASSWORD 环境变量")
    
    # 创建认证 header
    headers = create_basic_auth_header(username, password)
    
    # 连接到 Toolbox
    async with ToolboxClient(toolbox_url, headers=headers) as client:
        # 加载所有工具
        tools = await client.load_toolset()
        print(f"已加载 {len(tools)} 个工具")
        
        # 列出工具名称
        for tool in tools:
            print(f"  - {tool.name}: {tool.description}")


async def example_2_invoke_tool():
    """示例 2: 调用特定工具"""
    print("\n=== 示例 2: 调用工具 ===")
    
    toolbox_url = os.getenv("TOOLBOX_URL", "https://toolbox.example.com")
    username = os.getenv("TOOLBOX_USER", "admin")
    password = os.getenv("TOOLBOX_PASSWORD")
    
    headers = create_basic_auth_header(username, password)
    
    async with ToolboxClient(toolbox_url, headers=headers) as client:
        # 加载特定工具
        tool = await client.load_tool("list-tables")
        
        # 调用工具
        result = await tool()
        print(f"查询结果: {result}")


async def example_3_with_parameters():
    """示例 3: 带参数调用工具"""
    print("\n=== 示例 3: 带参数调用 ===")
    
    toolbox_url = os.getenv("TOOLBOX_URL", "https://toolbox.example.com")
    username = os.getenv("TOOLBOX_USER", "admin")
    password = os.getenv("TOOLBOX_PASSWORD")
    
    headers = create_basic_auth_header(username, password)
    
    async with ToolboxClient(toolbox_url, headers=headers) as client:
        # 加载需要参数的工具
        tool = await client.load_tool("query-data")
        
        # 调用工具并传递参数
        result = await tool(
            table_name="users",
            limit=10
        )
        print(f"查询结果: {result}")


async def example_4_error_handling():
    """示例 4: 错误处理"""
    print("\n=== 示例 4: 错误处理 ===")
    
    toolbox_url = os.getenv("TOOLBOX_URL", "https://toolbox.example.com")
    username = os.getenv("TOOLBOX_USER", "admin")
    password = "wrong-password"  # 故意使用错误密码
    
    headers = create_basic_auth_header(username, password)
    
    try:
        async with ToolboxClient(toolbox_url, headers=headers) as client:
            tools = await client.load_toolset()
    except Exception as e:
        print(f"预期的错误: {type(e).__name__}: {e}")
        print("这是正常的 - 密码错误应该被拒绝")


async def example_5_reusable_client():
    """示例 5: 可复用的客户端类"""
    print("\n=== 示例 5: 封装客户端类 ===")
    
    class ToolboxAuthClient:
        """封装了认证的 Toolbox 客户端"""
        
        def __init__(self, url: str, username: str, password: str):
            self.url = url
            self.headers = create_basic_auth_header(username, password)
            self._client: Optional[ToolboxClient] = None
        
        async def __aenter__(self):
            self._client = ToolboxClient(self.url, headers=self.headers)
            await self._client.__aenter__()
            return self
        
        async def __aexit__(self, *args):
            if self._client:
                await self._client.__aexit__(*args)
        
        async def get_tool(self, name: str):
            """获取工具"""
            if not self._client:
                raise RuntimeError("客户端未初始化")
            return await self._client.load_tool(name)
        
        async def list_tools(self):
            """列出所有工具"""
            if not self._client:
                raise RuntimeError("客户端未初始化")
            return await self._client.load_toolset()
    
    # 使用封装的客户端
    async with ToolboxAuthClient(
        url=os.getenv("TOOLBOX_URL", "https://toolbox.example.com"),
        username=os.getenv("TOOLBOX_USER", "admin"),
        password=os.getenv("TOOLBOX_PASSWORD", ""),
    ) as client:
        tools = await client.list_tools()
        print(f"通过封装客户端加载了 {len(tools)} 个工具")


async def main():
    """主函数"""
    print("MCP Toolbox Python 客户端示例")
    print("================================")
    
    # 检查环境变量
    if not os.getenv("TOOLBOX_PASSWORD"):
        print("\n错误: 请设置环境变量")
        print("  export TOOLBOX_URL=https://toolbox.example.com")
        print("  export TOOLBOX_USER=admin")
        print("  export TOOLBOX_PASSWORD=your-password")
        print("\n或创建 .env 文件:")
        print("  TOOLBOX_URL=https://toolbox.example.com")
        print("  TOOLBOX_USER=admin")
        print("  TOOLBOX_PASSWORD=your-password")
        return
    
    # 运行示例
    try:
        await example_1_basic_usage()
        # await example_2_invoke_tool()
        # await example_3_with_parameters()
        # await example_4_error_handling()
        # await example_5_reusable_client()
    except Exception as e:
        print(f"\n错误: {e}")
        print("请确保:")
        print("  1. Toolbox 服务正在运行")
        print("  2. 域名可以访问")
        print("  3. 用户名和密码正确")


if __name__ == "__main__":
    asyncio.run(main())
