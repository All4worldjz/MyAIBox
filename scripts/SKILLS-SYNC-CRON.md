# Agent Skills 每周自动同步配置
#
# 使用方法（选择一种）：
#
# 方法 1: 使用 cron（推荐 macOS/Linux）
# ----------------------------------------
# 编辑 crontab：
#   crontab -e
#
# 添加以下行（每周日 02:00 执行同步）：
#   0 2 * * 0 cd /Users/whoami2023/Documents/GitRepo/MyAIBox && ./scripts/sync-agent-skills.sh --check >> /tmp/skills-sync-cron.log 2>&1
#
# 如果有更新，手动运行同步：
#   cd /Users/whoami2023/Documents/GitRepo/MyAIBox && ./scripts/sync-agent-skills.sh
#
#
# 方法 2: 使用 launchd（macOS 推荐）
# ----------------------------------------
# 1. 复制 com.aibox.sync-skills.plist 到 ~/Library/LaunchAgents/
# 2. 加载配置：
#      launchctl load ~/Library/LaunchAgents/com.aibox.sync-skills.plist
# 3. 查看状态：
#      launchctl list | grep aibox
# 4. 卸载配置：
#      launchctl unload ~/Library/LaunchAgents/com.aibox.sync-skills.plist
#
#
# 方法 3: 使用 systemd timer（Linux 推荐）
# ----------------------------------------
# 1. 复制 aibox-sync-skills.service 和 aibox-sync-skills.timer 到 /etc/systemd/system/
# 2. 启用定时器：
#      sudo systemctl enable aibox-sync-skills.timer
#      sudo systemctl start aibox-sync-skills.timer
# 3. 查看状态：
#      systemctl status aibox-sync-skills.timer
# 4. 查看日志：
#      journalctl -u aibox-sync-skills.service


# ============================================================
# 详细 cron 配置示例
# ============================================================
#
# 每周日 02:00 执行检查（仅检查，不自动同步）
# 0 2 * * 0 cd /path/to/MyAIBox && ./scripts/sync-agent-skills.sh --check >> /tmp/skills-sync.log 2>&1
#
# 每周一 09:00 执行完整同步（自动拉取并更新）
# 0 9 * * 1 cd /path/to/MyAIBox && ./scripts/sync-agent-skills.sh >> /tmp/skills-sync.log 2>&1
#
# 每天 08:00 检查更新（适合开发期间频繁检查）
# 0 8 * * * cd /path/to/MyAIBox && ./scripts/sync-agent-skills.sh --check >> /tmp/skills-sync.log 2>&1


# ============================================================
# 故障排除
# ============================================================
#
# 问题: cron 执行失败
# 解决: 确保 cron 有正确的 PATH，在 crontab 顶部添加：
#   PATH=/usr/local/bin:/usr/bin:/bin
#
# 问题: git clone 失败
# 解决: 确保网络可访问 gitcode.com，可能需要配置代理
#
# 问题: 权限不足
# 解决: 确保脚本有执行权限：chmod +x scripts/sync-agent-skills.sh
#
# 查看同步日志:
#   cat /tmp/skills-sync-*.log | tail -50
#
# 手动触发同步:
#   ./scripts/sync-agent-skills.sh
#
# 检查更新状态:
#   ./scripts/sync-agent-skills.sh --check
