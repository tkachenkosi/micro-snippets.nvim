-- ~/.config/nvim/lua/simple-snippets/init.lua
local M = {}

M.config = {
    snippets_dir = vim.fn.stdpath('config') .. '/snippets',
    keymap = '<C-j>',
    auto_reload = true,   -- автоматически перезагружать кеш при изменении файлов сниппетов
		-- multiline_indent = "prefix",   -- "prefix" или "none"
		multiline_indent = true,   -- "prefix" или "none"
}

-- Кеш: [filetype] = { snippets = {trigger=body}, mtime = number }
M.cache = {}

-- Вспомогательная функция для получения пути к файлу сниппетов
function M.get_snippet_filepath(filetype)
    return vim.fs.normalize(M.config.snippets_dir .. '/' .. filetype .. '.snippets')
end

-- Парсинг файла сниппетов (возвращает таблицу {trigger = body} или nil)
function M.parse_snippets(filepath)
    -- проверка существования и читаемости через vim.uv.fs_stat (асинхронный интерфейс, но используем синхронный вызов)
    local stat = vim.uv.fs_stat(filepath)
    if not stat or stat.type ~= 'file' then
        return nil
    end

    local lines = vim.fn.readfile(filepath)
    if not lines or #lines == 0 then
        return nil
    end

    local snippets = {}
    local current_trigger = nil
    local current_body = {}

    for _, line in ipairs(lines) do
        local trigger_match = line:match("^%-%-%-([^%s]+)$")
        if trigger_match then
            if current_trigger and #current_body > 0 then
                snippets[current_trigger] = table.concat(current_body, "\n")
            end
            current_trigger = trigger_match
            current_body = {}
        else
            if current_trigger then
                table.insert(current_body, line)
            end
        end
    end

    if current_trigger and #current_body > 0 then
        snippets[current_trigger] = table.concat(current_body, "\n")
    end

    return snippets, stat.mtime
end

-- Загрузка сниппетов для filetype с проверкой mtime (кеш обновляется при изменении)
function M.load_snippets(filetype)
    local filepath = M.get_snippet_filepath(filetype)
    local cached = M.cache[filetype]
    local current_stat = vim.uv.fs_stat(filepath)

    -- Если файл отсутствует
    if not current_stat then
        if cached then
            M.cache[filetype] = nil
        end
        return nil
    end

    -- Если кеш есть и mtime не изменился
    if cached and cached.mtime == current_stat.mtime then
        return cached.snippets
    end

    -- Иначе парсим заново
    local snippets, mtime = M.parse_snippets(filepath)
    if snippets then
        M.cache[filetype] = { snippets = snippets, mtime = mtime }
        return snippets
    end
    return nil
end

-- Автообновление кеша при изменении файлов (опционально)
if M.config.auto_reload then
    local augroup = vim.api.nvim_create_augroup("SimpleSnippetsReloader", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = augroup,
        pattern = M.config.snippets_dir .. '/*.snippets',
        callback = function()
            M.reload_cache()
            vim.notify("SimpleSnippets: кеш обновлён", vim.log.levels.INFO)
        end,
    })
end

-- Определение триггера перед курсором (с учётом границ идентификатора)
-- Используем Lua-паттерн: ищем последовательность символов, не являющихся пробельными,
-- и также не являющихся пунктуацией (настраивается). Для простоты: любые символы кроме пробелов и табуляции.
function M.get_trigger_before_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
    if col == 0 then return nil, nil end

    -- Находим начало слова (Lua паттерн: символы, не являющиеся пробелами)
    -- Идём от col влево, пока не пробел
    local start = col
    while start > 0 and line:sub(start, start):match("%S") do
        start = start - 1
    end
    if start < col then start = start + 1 end

    local trigger = line:sub(start, col)
    if trigger == "" then return nil, nil end
    return trigger, start - 1  -- 0-index позиция начала
end

-- Вставка сниппета с поддержкой простейших заполнителей ($1, $2, ...)
function M.insert_snippet(trigger, snippet_text, start_pos)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""

    -- Если start_pos не передан, вычисляем (как раньше)
    if not start_pos then
        local s = col
        while s > 0 and line:sub(s, s):match("%S") do
            s = s - 1
        end
        start_pos = (s < col and s + 1) or 1
        start_pos = start_pos - 1   -- 0-index
    end

    -- Извлекаем префикс (от начала строки до start_pos) – сохраняем все символы, включая табуляции
    local prefix = line:sub(1, start_pos) or ""

    -- Разбиваем сниппет на строки
    local lines = vim.split(snippet_text, "\n", { plain = true })

    -- Добавляем префикс ко всем строкам, начиная со второй
    if  M.config.multiline_indent and #lines > 1 and prefix ~= "" then
        for i = 2, #lines do
            lines[i] = prefix .. lines[i]
        end
    end

    -- Заменяем триггер на подготовленные строки
    vim.api.nvim_buf_set_text(0, row, start_pos, row, col, lines)

    -- Простейшая поддержка табуляции: ищем $1, $2, ... (только в первой строке для упрощения)
    -- Но лучше сделать честный поиск по всему вставленному тексту:
    -- Получаем новые позиции после вставки (можно через nvim_buf_get_text, но проще:
    -- переходим к началу вставки и используем поиск)
    local first_line = lines[1] or ""
    local placeholder = first_line:match("%$([1-9])")
    if placeholder then
        local new_row = row
        local new_col = start_pos + (first_line:find("%$" .. placeholder, 1, true) or 1) - 1
        vim.api.nvim_win_set_cursor(0, { new_row + 1, new_col })
    end
end

-- Основная функция расширения
function M.expand_snippet()
    local trigger, start_pos = M.get_trigger_before_cursor()
    if not trigger then
        vim.notify("[SimpleSnippets] Нет триггера перед курсором", vim.log.levels.INFO)
        return
    end

    local filetype = vim.bo.filetype
    if filetype == "" then
        vim.notify("[SimpleSnippets] Не удалось определить тип файла", vim.log.levels.WARN)
        return
    end

    local snippets = M.load_snippets(filetype)
    if not snippets then
        vim.notify(string.format("[SimpleSnippets] Файл сниппетов не найден: %s.snippets", filetype), vim.log.levels.WARN)
        return
    end

    local snippet_body = snippets[trigger]
    if not snippet_body then
        vim.notify(string.format("[SimpleSnippets] Сниппет '%s' не найден для типа %s", trigger, filetype), vim.log.levels.INFO)
        return
    end

    M.insert_snippet(trigger, snippet_body, start_pos)
end

-- Перезагрузка кеша (полная очистка)
function M.reload_cache()
    M.cache = {}
    vim.notify("[SimpleSnippets] Кеш полностью очищен", vim.log.levels.INFO)
end

-- Настройка плагина
function M.setup(user_config)
    user_config = user_config or {}
    M.config = vim.tbl_deep_extend("force", M.config, user_config)

    -- Создаём папку для сниппетов, если её нет
    if vim.fn.isdirectory(M.config.snippets_dir) == 0 then
        vim.fn.mkdir(M.config.snippets_dir, "p")
    end

    -- Назначаем клавишу
    vim.keymap.set('i', M.config.keymap, M.expand_snippet, { desc = "Expand snippet (SimpleSnippets)" })

    -- Команда :SimpleSnippetsReload
    vim.api.nvim_create_user_command('SimpleSnippetsReload', function()
        M.reload_cache()
    end, {})
end

return M
