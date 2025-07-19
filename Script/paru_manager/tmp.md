编写一个用于archlinux上管理paru软件管理的python tui脚本
设计理念：借鉴mvc设计理念，多文件分离数据操作代码，后端实现代码，前端tui代码和业务逻辑代码

---
# 全局变量：
`glb_upgrade_list`：数据类型为 `[["包名","更新前版本号","更新后版本号"], ...]`
`glb_upgrade_ignore_list`：数据类型为 `["包名", ...]`
`glb_downgrade_list`：数据类型为  `[["包名","降级前版本号","降级后版本号"], ...]`
`glb_downgrade_ignore_list`：数据类型为 `["包名", ...]`
`glb_data`：存储的是json文件里的内容

---
# 程序主入口：
检测此项目所需软件是否安装完整，缺失软件则使用paru安装。检测json文件的完整性，初始化全局变量，调用业务逻辑处理代码

---
# json数据操作代码实现：
json文件完整性校验的实现与封装。json文件格式化的实现与封装。json数据增删改查的实现与封装。
整个项目所有对json文件的操作都通过调用此处提供的方法实现
json的结构如下
```json
{
    "package":{
        "upgrade":{
            "from":"",  //值为软件更新成功前的版本号
            "to":"",  //值为软件更新成功后的版本号
            "time":""  //值为软件更新成功时的日期时间
        },
        "downgrade":{
            "from":"",  //转为软件降级成功前的版本号
            "to":"",  //值为软件降级成功后的版本号
            "time":"",  //值为软件降级成功时的日期时间
        },
        "ignore":{
            "upgrade":[  //列表最大长度为10，超过最大长度时自动删除最早添加的元素
                "",  //元素为软件版本号
                ...
            ],
            "downgrade":["",...] // 和"upgrade"一样
        }
    },
    ...
}
```


实现`set_upgrade()`
接收变量`package_name`,`from`,`to`
获取当前系统时间并赋值给新变量`time`
按以下的方式，将数据更新到json中
`package_name.upgrade.from`=`from`
`package_name.upgrade.to`=`to`
`package_name.upgrade.time`=`time`

实现`set_downgrade()`
接收变量`package_name`,`from`,`to`
获取当前系统时间并赋值给新变量`time`
按以下的方式，将数据更新到json中
`package_name.downgrade.from`=`from`
`package_name.downgrade.to`=`to`
`package_name.downgrade.time`=`time`

实现`set_ignore_upgrade()`
接收变量`package_name`,`ignore_upgrade_list`
按以下的方式，将数据更新到json中
`package_name.ignore.upgrade`=`ignore_upgrade_list`

实现`set_ignore_downgrade()`
接收变量`package_name`,`ignore_downgrade_list`
按以下的方式，将数据更新到json中
`package_name.ignore.downgrade`=`ignore_downgrade_list`

实现`get_upgrade_from()`,`get_upgrade_to()`,`get_upgrade_time()`,`get_downgrade_from()`,`get_downgrade_to()`,`get_downgrade_time()`,`get_ignore_upgrade()`,`get_ignore_downgrade()`，它们都需要接收包名来确定要返回的数据

实现读取json数据文件所有数据的方法`get_data()`
将读取的结果赋值给全局变量`glb_data`

实现检测数据格式是否匹配的方法`check_data_format()`
接收变量`pkg_name`，可缺省
当`pkg_name`缺省时，判断全局变量`glb_data`格式是否匹配`{"":{},"":{},...}`，是则返回真，否则返回假
当`pkg_name`未缺省时，判断全局变量`glb_data`中是否有`$pkg_name`的对象，并且`$pkg_name`的值是否匹配`{"upgrade":{}, "downgrade":{}, "ignore":{}}`，是则返回真，否则返回假

实现json数据文件的格式化方法`format_data()`
接收json变量，调用`check_data_format()`，返回值为真时不做任何操作，返回值为假时将json文件用`{}`覆盖

实现格式化json文件中某个对象值的方法`format_data_package()`
接收变量`pkg_name`
用下面的格式更新json文件中对应的键值对
```json
{
    $package_name:{
        "upgrade":{
            "from":"",
            "to":"",
            "time":""
        },
        "downgrade":{
            "from":"",
            "to":"",
            "time"
        },
        "ignore":{
            "upgrade":[],
            "downgrade":[]
        }
    }
}
```


---
# 后端代码实现：
获取软件版本号的实现与封装`get_pkg_version()`:
接收一个包名字符串`pkg_name`
使用终端命令`paru -Qi "$pkg_name" 2>/dev/null | grep -E '^版本' | awk '{print $3}'`获取`pkg_name`当前版本号
return软件当前版本号

设置软件更新列表的实现与封装`set_upgrade_list()`:
接收全局变量`glb_upgrade_list`
使用终端命令`paru -Qu`检测可更新的软件，其返回的结果格式为
```
hyprgraphics-git 0.1.3.r1.g6075491-4 -> 0.1.3.r4.gc7225d7-1
flameshot-git r2024.88c738ff-1 -> latest-commit
...
```
第一列为可以更新的软件包名，第二列为更新前的软件版本号，第四列为更新后的软件版本号
处理返回结果，将结果以`["包名", "更新前版本号", "更新后版本号"]`的形式添加到`glb_upgrade_list`中

设置软件更新忽略列表的实现与封装`set_upgrade_ignore_list()`
接收变量`upgrade_ignore`，它的值是一个包名字符串
将`upgrade_ignore`追加到全局变量`glb_upgrade_ignore_list`中

设置软件降级列表的实现与封装`set_downgrade_list()`:
读取json文件的所有数据并赋值给变量`json_data`
遍历`json_data`所有元素，检测到有软件的upgrade.from有内容且upgrade.time<72小时后，将其以数据`["package", "upgrade.to", "upgrade.from"]`的形式添加到全局变量`glb_downgrade_list`中

设置软件降级忽略列表的实现与封装`set_downgrade_ignore_list()`:
接收变量`downgrade_ignore`，它的值是一个包名字符串
将`downgrade_ignore`追加到全局变量`glb_downgrade_ignore_list`中

更新软件的实现与封装`upgrade_pkg()`:
接收变量`pkg_upgrade`
调用`get_pkg_version($pkg_upgrade)`获取软件更新前版本号，并将返回值赋值给新变量`before_version`
使用终端命令`paru -S "$pkg_upgrade" --noconfirm`更新软件
调用`get_pkg_version($pkg_upgrade)`获取软件更新后版本号，并将返回值赋值给新变量`after_version`
如果`before_version`!=`after_version`，则更新成功，调用`set_upgrade()`方法，更新json文件数据

批量更新软件的实现与封装`upgrade_pkgs()`:
循环判断`glb_upgrade_list`每个列表中元素的第一个子元素是否在`glb_upgrade_ignore_list`中，是的话不做任何操作进入下一次判断，否的话将此元素追加到新变量`final_upgrade_list`中，然后进入下一次判断
循环判断`final_upgrade_list`每个列表元素的第三个子元素是否在`get_ignore_upgrade(package_name)`的返回列表中，是的话将其从`final_upgrade_list`中移除，然后进入下一次判断，否的话直接进入下一次判断
将`final_upgrade_list`所有元素的第一个子元素以字符串的形式拼接起来，用空格隔开，将结果赋值给新变量`pkg_upgrade`
使用终端命令`paru -S "$pkg_upgrade" --noconfirm`更新软件
更新完成后调用`get_pkg_version()`获取`final_upgrade_list`中每个元素的第一个子元素的当前版本号，判断其是否等于该列表第三个子素元素所表示的版本号，是则表示此软件更新成功，否则更新失败。更新成功的软件调用`set_upgrade()`方法，更新json文件数据

降级软件的实现与封装`downgrade_pkg()`:
接收变量`pkg_name`
调用`get_pkg_version($pkg_name)`获取软件降级前版本号，并将返回值赋值给新变量`before_version`
调用`get_upgrade_from($pkg_name)`获取软件降级目标版本号，并将返回值赋值给新变量`target_version`
使用终端命令`sudo downgrade "$pkg_name=$target_version -- --noconfirm`降级软件
调用`get_pkg_version($pkg_upgrade)`获取软件更新后版本号，并将返回值赋值给新变量`after_version`
如果`target_version`==`after_version`，则更新成功，调用`set_downgrade()`方法，更新json文件数据

批量降级软件的实现与封装`downgrade_pkgs()`:
循环判断`glb_downgrade_list`每个列表元素的第一个子元素是否在`glb_downgrade_ignore_list`中，是的话不做任何操作进入下一次判断，否的话将此元素追加到新变量`final_downgrade_list`中，然后进入下一次判断
循环判断`final_downgrade_list`每个列表元素的第三个子元素是否在`get_ignore_downgrade(package_name)`返回的列表中，是的话将其从`final_downgrade_list`中移除，然后进入下一次判断，否的话直接进入下一次判断
声明空的字符串变量`pkg_versions`
进入循环体，遍历`final_downgrade_list`的每个元素：循环体中将每个元素的第一个子元素赋值给新变量`pkg_name`，将每个元素的第三个子元素赋值给新变量`target_version`，然后以`"$pkg_name=$target_version "`的字符串形式追加到`pkg_versions`中
然后使用终端命令`sudo downgrade "$pkg_versions" -- --noconfirm `降级软件
降级完成后调用`get_pkg_version()`获取`final_downgrade_list`列表中每个元素的第一个子元素的当前版本号，判断其是否等于该列表第三个子元素所表示的版本号，是则表示此软件降级成功，否则降级失败。降级成功的软件调用`set_downgrade()`方法，更新json文件数据


---
# 前端tui格式实现：
主菜单`main_menu()`：
打印：功能菜单：
打印：u - 软件更新
打印：d - 软件降级
打印：h - 历史记录
打印：q - 退出程序

软件更新子菜单`upgrade_menu()`：
打印：有以下软件可更新
打印：（多行，解析全局变量`glb_upgrade_list`，每行打印软件包名  当前版本号 --> 更新目标版本号）
打印：a - 全部更新
打印：i - 不更新指定软件
打印：o - 只更新指定软件
打印：b - 回到主菜单
打印：q - 退出程序

软件降级子菜单`downgrade_menu()`：
打印：有以下软件可降级
打印：（多行，解析全局变量`glb_downgrade_list`，每行打印软件包名  当前版本号 --> 降级目标版本号）
打印：a - 全部降级
打印：i - 不降级指定软件
打印：o - 只降级指定软件
打印：b - 回到主菜单
打印：q - 退出程序

历史记录子菜单`history_menu()`：
打印：最近三天升级记录
打印：（多行，解析软件升级列表，每行打印软件包名  更新前版本号 --> 更新后版本号
打印：

---
# 业务逻辑代码实现：
主菜单：打印功能菜单，等待用户选择

软件更新功能：调用更新检测功能，打印可更新软件列表，打印软件更新子菜单，等待用户选择

软件更新子菜单：
全部更新：调用后端实现代码，更新所有可更新软件，完成后退出程序

