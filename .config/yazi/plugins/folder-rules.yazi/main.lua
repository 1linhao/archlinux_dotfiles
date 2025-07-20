local function setup()
    -- 用户可自定义的目录列表
    local target_dirs = {
        "Downloads",
        "Screenshots",
        "Recording",
        -- 在此处添加更多目录名
    }

    ps.sub("cd", function()
        local cwd = cx.active.current.cwd
        local is_target_dir = false

        -- 检查当前目录是否在目标目录列表中
        for _, dir in ipairs(target_dirs) do
            if cwd:ends_with(dir) then
                is_target_dir = true
                break
            end
        end

        if is_target_dir then
            -- 目标目录按修改时间从新到旧排序
            ya.emit("sort", { "mtime", reverse = true, dir_first = false })
        else
            -- 其他目录按字母顺序排序
            ya.emit("sort", { "alphabetical", reverse = false, dir_first = true })
        end
    end)
end

return { setup = setup }
