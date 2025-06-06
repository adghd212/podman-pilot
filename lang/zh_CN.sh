#!/bin/bash
# 简体中文语言文件 - Podman Pilot

# --- 通用 ---
LANG_ERROR="错误"
LANG_SUCCESS="成功"
LANG_INFO="信息"
LANG_WARNING="警告"
LANG_OK="确定"
LANG_CANCEL="取消"
LANG_YES="是"
LANG_NO="否"
LANG_BACK="返回"
LANG_EXIT="退出"
LANG_PLEASE_WAIT="请稍候..."
LANG_SELECT_AN_OPTION="请选择一个选项："
LANG_INVALID_OPTION="无效选项。"
LANG_PRESS_ANY_KEY="按任意键继续..."
LANG_NOT_IMPLEMENTED_YET="此功能尚未实现。"
LANG_OPERATION_SUCCESSFUL="操作成功。"
LANG_OPERATION_FAILED="操作失败。"
LANG_CONFIRM_ACTION="确认操作"
LANG_ARE_YOU_SURE="您确定吗？"
LANG_ENTER_VALUE_FOR="请输入 %s 的值:"
LANG_OPTIONAL_LEAVE_BLANK=" (可选, 若不需要则留空)"
LANG_REQUIRED_FIELD="此字段为必填项。"
LANG_EXITING_MSG="正在退出 Podman Pilot。"
LANG_NO_ITEMS_FOUND="未找到任何项目。"

# --- 主菜单 (podman-pilot.sh) ---
LANG_MAIN_MENU_BACKTITLE="Podman Pilot - by adghd212"
LANG_MAIN_MENU_TITLE="主菜单"
LANG_MENU_INSTALL_PODMAN="安装/管理 Podman"
LANG_MENU_MANAGE_REGISTRIES="管理镜像源"
LANG_MENU_MANAGE_PODS="管理 Pod"
LANG_MENU_MANAGE_IMAGES="管理镜像"
LANG_MENU_MANAGE_CONTAINERS="管理容器"
LANG_MENU_ONE_CLICK_APPS="一键部署应用"
LANG_MENU_UPDATE_SCRIPT="更新 Podman Pilot"
LANG_MENU_SWITCH_LANGUAGE="切换语言"
LANG_SELF_NAME_ZH_CN="简体中文 (Chinese Simplified)" # 用于语言切换器

# --- Podman 安装 (install_podman.sh) ---
LANG_PODMAN_MENU_TITLE="Podman 管理"
LANG_PODMAN_INSTALL="安装 Podman"
LANG_PODMAN_UNINSTALL="卸载 Podman"
LANG_PODMAN_STATUS="检查 Podman 状态"
LANG_PODMAN_INSTALL_CONFIRM="未检测到 Podman 或未找到。现在安装吗 (需要sudo权限)？"
LANG_PODMAN_INSTALLING="正在安装 Podman..."
LANG_PODMAN_INSTALL_SUCCESS="Podman 安装成功。"
LANG_PODMAN_INSTALL_FAILED="Podman 安装失败。请检查 APT 日志。"
LANG_PODMAN_UNINSTALL_CONFIRM="您确定要卸载 Podman 吗？如果选择清除，可能会删除所有 Podman 数据。"
LANG_PODMAN_UNINSTALL_PURGE_CONFIRM="同时清除 Podman 系统数据 (镜像、容器等) 吗？此操作不可逆！"
LANG_PODMAN_UNINSTALLING="正在卸载 Podman..."
LANG_PODMAN_UNINSTALL_SUCCESS="Podman 卸载成功。"
LANG_PODMAN_UNINSTALL_FAILED="Podman 卸载失败。"
LANG_PODMAN_ALREADY_INSTALLED="Podman 已安装。"
LANG_PODMAN_NOT_INSTALLED="Podman 未安装。"
LANG_PODMAN_VERSION_INFO="Podman 版本信息："
LANG_PODMAN_SERVICE_STATUS="Podman 服务/套接字状态："
LANG_PODMAN_CHECK_MANUAL="请使用 'podman version' 和 'systemctl status podman.socket' 手动检查 Podman 状态。"

# --- 镜像源 (manage_registries.sh) ---
LANG_REGISTRIES_MENU_TITLE="镜像源管理"
LANG_REGISTRIES_VIEW_CURRENT="查看当前镜像源"
LANG_REGISTRIES_ADD_SEARCH="添加搜索镜像源 (用户级)"
LANG_REGISTRIES_REMOVE_SEARCH="移除搜索镜像源 (用户级)"
LANG_REGISTRIES_ADD_INSECURE="添加不安全镜像源 (用户级)" # 本地开发用, 谨慎使用
LANG_REGISTRIES_REMOVE_INSECURE="移除不安全镜像源 (用户级)"
LANG_REGISTRIES_EDIT_FILE_PROMPT="直接编辑 %s 文件吗？ (实验性功能)"
LANG_REGISTRIES_USER_CONF_PATH="用户配置: %s"
LANG_REGISTRIES_SYSTEM_CONF_PATH="系统配置: %s"
LANG_REGISTRIES_NO_USER_CONF="未找到用户 registries.conf 文件。如果添加镜像源，将会自动创建。"
LANG_REGISTRIES_SYSTEM_INFO="系统级镜像源通常位于 /etc/containers/registries.conf (编辑需要root权限)。"
LANG_REGISTRIES_ENTER_URL="输入镜像源 URL (例如 docker.io, quay.io, my.registry:5000):"
LANG_REGISTRIES_SELECT_TO_REMOVE="选择要移除的镜像源:"
LANG_REGISTRIES_MODIFIED_SUCCESS="镜像源配置已修改。某些更改可能需要重启 Podman 或执行 'podman system reset' 才能完全生效。"
LANG_REGISTRIES_MODIFIED_FAILED="修改镜像源配置失败。"
LANG_REGISTRIES_INVALID_URL="输入的镜像源 URL 无效。"
LANG_REGISTRIES_ALREADY_EXISTS="镜像源 '%s' 已存在于搜索列表中。"
LANG_REGISTRIES_NOT_FOUND="在搜索列表中未找到镜像源 '%s'。"
LANG_REGISTRIES_PREDEFINED_TITLE="从预定义镜像源中选择或选择自定义："
LANG_REGISTRIES_CUSTOM_OPTION="自定义镜像源..."

# --- Pods (manage_pods.sh) ---
LANG_PODS_MENU_TITLE="Pod 管理"
LANG_PODS_LIST="列出 Pod"
LANG_PODS_CREATE="创建 Pod"
LANG_PODS_DELETE="删除 Pod"
LANG_PODS_INSPECT="检查 Pod"
LANG_PODS_START="启动 Pod"
LANG_PODS_STOP="停止 Pod"
LANG_PODS_RESTART="重启 Pod"
LANG_PODS_KILL="杀死 Pod"
LANG_PODS_PAUSE="暂停 Pod"
LANG_PODS_UNPAUSE="取消暂停 Pod"
LANG_PODS_ENTER_NAME="输入 Pod 名称:"
LANG_PODS_ENTER_PORTS="输入端口映射 (例如 8080:80,443:443 或留空):"
LANG_PODS_SHARE_NET_PID_IPC="与此 Pod 共享 net, pid, ipc 命名空间 (逗号分隔, 例如 net,pid 或 host)?"
LANG_PODS_CREATING="正在创建 Pod '%s'..."
LANG_PODS_CREATED_SUCCESS="Pod '%s' 创建成功。"
LANG_PODS_CREATE_FAILED="创建 Pod '%s' 失败。"
LANG_PODS_DELETING="正在删除 Pod '%s'..."
LANG_PODS_DELETED_SUCCESS="Pod '%s' 删除成功。"
LANG_PODS_DELETE_FAILED="删除 Pod '%s' 失败。"
LANG_PODS_NO_PODS_FOUND="未找到任何 Pod。"
LANG_PODS_SELECT_POD="选择一个 Pod:"
LANG_PODS_INSPECTING="正在检查 Pod '%s'..."
LANG_PODS_STARTING="正在启动 Pod '%s'..."
LANG_PODS_STARTED_SUCCESS="Pod '%s' 启动成功。"
LANG_PODS_START_FAILED="启动 Pod '%s' 失败。"
LANG_PODS_STOPPING="正在停止 Pod '%s'..."
LANG_PODS_STOPPED_SUCCESS="Pod '%s' 停止成功。"
LANG_PODS_STOP_FAILED="停止 Pod '%s' 失败。"
LANG_PODS_RESTARTING="正在重启 Pod '%s'..."
LANG_PODS_KILLING="正在杀死 Pod '%s'..."
LANG_PODS_PAUSING="正在暂停 Pod '%s'..."
LANG_PODS_UNPAUSING="正在取消暂停 Pod '%s'..."

# --- Images (manage_images.sh) ---
LANG_IMAGES_MENU_TITLE="镜像管理"
LANG_IMAGES_LIST="列出镜像"
LANG_IMAGES_PULL="拉取镜像"
LANG_IMAGES_REMOVE="移除镜像"
LANG_IMAGES_SEARCH="搜索镜像 (在镜像源上)"
LANG_IMAGES_PRUNE="清理未使用镜像"
LANG_IMAGES_INSPECT="检查镜像"
LANG_IMAGES_ENTER_NAME_TAG="输入镜像名称和标签 (例如 nginx:latest):"
LANG_IMAGES_PULLING="正在拉取镜像 '%s'..."
LANG_IMAGES_PULLED_SUCCESS="镜像 '%s' 拉取成功。"
LANG_IMAGES_PULL_FAILED="镜像 '%s' 拉取失败。"
LANG_IMAGES_DELETING="正在删除镜像 '%s'..."
LANG_IMAGES_DELETED_SUCCESS="镜像 '%s' 删除成功。"
LANG_IMAGES_DELETE_FAILED="删除镜像 '%s' 失败。它可能正在被某个容器使用。"
LANG_IMAGES_NO_IMAGES_FOUND="未找到任何镜像。"
LANG_IMAGES_SELECT_IMAGE="选择一个镜像:"
LANG_IMAGES_PRUNING="正在清理未使用镜像..."
LANG_IMAGES_PRUNED_SUCCESS="未使用镜像已清理。"
LANG_IMAGES_PRUNE_FAILED="清理镜像失败。"
LANG_IMAGES_SEARCH_TERM="输入镜像搜索词:"
LANG_IMAGES_SEARCHING="正在搜索 '%s'..."
LANG_IMAGES_INSPECTING="正在检查镜像 '%s'..."

# --- Containers (manage_containers.sh) ---
LANG_CONTAINERS_MENU_TITLE="容器管理"
LANG_CONTAINERS_LIST_ALL="列出所有容器"
LANG_CONTAINERS_LIST_RUNNING="列出运行中容器"
LANG_CONTAINERS_CREATE="创建容器 (基础)"
LANG_CONTAINERS_DELETE="删除容器"
LANG_CONTAINERS_START="启动容器"
LANG_CONTAINERS_STOP="停止容器"
LANG_CONTAINERS_RESTART="重启容器"
LANG_CONTAINERS_LOGS="查看容器日志"
LANG_CONTAINERS_INSPECT="检查容器"
LANG_CONTAINERS_EXEC="在容器中执行命令"
LANG_CONTAINERS_PRUNE="清理已停止容器"
LANG_CONTAINERS_KILL="杀死容器"
LANG_CONTAINERS_PAUSE="暂停容器"
LANG_CONTAINERS_UNPAUSE="取消暂停容器"
LANG_CONTAINERS_NO_CONTAINERS_FOUND="未找到任何容器。"
LANG_CONTAINERS_SELECT_CONTAINER="选择一个容器:"
LANG_CONTAINERS_SELECT_IMAGE_FOR_CREATE="为新容器选择镜像:"
LANG_CONTAINERS_ENTER_NAME="输入容器名称 (可选):"
LANG_CONTAINERS_ENTER_PORTS="输入端口映射 (例如 8080:80):"
LANG_CONTAINERS_ENTER_VOLUMES="输入卷映射 (例如 /host/path:/container/path:Z):"
LANG_CONTAINERS_ENTER_ENV_VARS="输入环境变量 (例如 VAR1=val1,VAR2=val2):"
LANG_CONTAINERS_ENTER_COMMAND="输入在容器内运行的命令 (可选):"
LANG_CONTAINERS_DETACH_MODE="以分离模式运行 (后台运行)？"
LANG_CONTAINERS_ASSIGN_TO_POD="分配到 Pod？(输入 Pod 名称或留空):"
LANG_CONTAINERS_CREATING="正在创建容器..."
LANG_CONTAINERS_CREATED_SUCCESS="容器创建成功。ID: %s"
LANG_CONTAINERS_CREATE_FAILED="创建容器失败。"
LANG_CONTAINERS_DELETING="正在删除容器 '%s'..."
LANG_CONTAINERS_DELETED_SUCCESS="容器 '%s' 删除成功。"
LANG_CONTAINERS_DELETE_FAILED="删除容器 '%s' 失败。"
LANG_CONTAINERS_STARTING="正在启动容器 '%s'..."
LANG_CONTAINERS_STARTED_SUCCESS="容器 '%s' 已启动。"
LANG_CONTAINERS_START_FAILED="启动容器 '%s' 失败。"
LANG_CONTAINERS_STOPPING="正在停止容器 '%s'..."
LANG_CONTAINERS_STOPPED_SUCCESS="容器 '%s' 已停止。"
LANG_CONTAINERS_STOP_FAILED="停止容器 '%s' 失败。"
LANG_CONTAINERS_VIEWING_LOGS="正在查看 '%s' 的日志。按 Ctrl+C 停止。"
LANG_CONTAINERS_ENTER_EXEC_CMD="输入要在 '%s' 中执行的命令:"
LANG_CONTAINERS_PRUNING="正在清理已停止的容器..."
LANG_CONTAINERS_PRUNED_SUCCESS="已停止
