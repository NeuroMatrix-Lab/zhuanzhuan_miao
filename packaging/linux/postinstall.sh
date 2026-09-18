#!/bin/sh
# RPM 安装后刷新桌面数据库（失败不影响安装）
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
