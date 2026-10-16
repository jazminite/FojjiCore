--[[
    FojjiCore Translation System

    Provides a shared localization API for FojjiCore and WeakAuras.

    Usage:

        FojjiCore.T("BOMB_ON_YOU")
            Returns the translation exactly as defined in the dictionary.

        FojjiCore.T("BOMB_ON_YOU", true)
            Returns the translation in uppercase.

        FojjiCore.TranslateLocale("zhCN", "BOMB_ON_YOU")
            Returns the Chinese translation regardless of the current client locale.

        FojjiCore.TranslateLocale("zhCN", "BOMB_ON_YOU", true)
            Returns the Chinese translation in uppercase where applicable.
]]

FojjiCore = FojjiCore or {}

------------------------------------------------------------
-- Translation Storage
------------------------------------------------------------

FojjiCore.Translations = FojjiCore.Translations or {}


------------------------------------------------------------
-- Register Translations
------------------------------------------------------------

function FojjiCore.RegisterTranslations(locale, translations)
    if not locale or not translations then
        return
    end

    FojjiCore.Translations[locale] = translations
end


------------------------------------------------------------
-- Translate
--
-- key   = Translation key
-- upper = Optional boolean. If true, return uppercase.
------------------------------------------------------------

function FojjiCore.Translate(key, upper)
    if not key then
        return ""
    end

    local locale = GetLocale()
    local translations = FojjiCore.Translations[locale]

    local text

    -- Try the current WoW locale
    if translations and translations[key] then
        text = translations[key]
    end

    -- Fall back to English
    if not text then
        local english = FojjiCore.Translations.enUS

        if english and english[key] then
            text = english[key]
        end
    end

    -- No translation found
    if not text then
        text = key
    end

    -- Optional uppercase formatting
    if upper then
        text = string.upper(text)
    end

    return text
end


------------------------------------------------------------
-- Translate Specific Locale
--
-- locale = WoW locale, e.g. "zhCN"
-- key    = Translation key
-- upper  = Optional boolean. If true, return uppercase.
------------------------------------------------------------

function FojjiCore.TranslateLocale(locale, key, upper)
    if not locale or not key then
        return key or ""
    end

    local translations = FojjiCore.Translations[locale]

    local text

    -- Try requested locale
    if translations and translations[key] then
        text = translations[key]
    end

    -- Fall back to English
    if not text then
        local english = FojjiCore.Translations.enUS

        if english and english[key] then
            text = english[key]
        end
    end

    -- No translation found
    if not text then
        text = key
    end

    -- Optional uppercase formatting
    if upper then
        text = string.upper(text)
    end

    return text
end


------------------------------------------------------------
-- Short Alias
--
-- Allows WeakAuras to use:
--
--     FojjiCore.T("BOMB_ON_YOU")
--
-- or:
--
--     FojjiCore.T("BOMB_ON_YOU", true)
--
------------------------------------------------------------

FojjiCore.T = FojjiCore.Translate