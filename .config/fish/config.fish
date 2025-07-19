if status is-interactive
    # Commands to run in interactive sessions can go here
end

# yazi 
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

abbr m musicfox
abbr r rmpc
abbr n ncmpcpp
abbr f fanyi
abbr b btop
abbr e exit

# dotfile
abbr dotfiles 'git --git-dir=$HOME/dotfiles/ --work-tree=$HOME'

abbr snvim sudo -E nvim

# systemctl
abbr spo systemctl poweroff
abbr sre systemctl reboot
abbr ssu systemctl suspend
abbr shi systemctl hibernate
abbr sstart sudo systemctl start
abbr sstop sudo systemctl stop
abbr srestart sudo systemctl restart
abbr senable sudo systemctl enable
abbr sdisable sudo systemctl disable
abbr sstatus sudo systemctl status

# 显示器管理
abbr mec bash $HOME/Script/monitor_control.sh mec
abbr meo bash $HOME/Script/monitor_control.sh meo
abbr mhc bash $HOME/Script/monitor_control.sh mhc
abbr mho bash $HOME/Script/monitor_control.sh mho
abbr mhr bash $HOME/Script/monitor_control.sh mhr
