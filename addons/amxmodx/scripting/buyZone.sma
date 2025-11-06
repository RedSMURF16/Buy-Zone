/*
*
*	Buy Zone by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /bz                 "Opens the Buy Zone menu."
*       say_team /bz            "Opens the Buy Zone menu."
*       say /buyzone            "Opens the Buy Zone menu."
*       say_team /buyzone       "Opens the Buy Zone menu."
*       bz_reload               "Reloads the configuration file."
*       buyzone_reload          "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT         32
#define MENU_BLINK      0.1

new const PLUGIN_VERSION[]       = "1.0"
new const Float:DELAY_ON_CONNECT = 1.0
new const ERROR_FILE[]           = "BuyZone_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS
}

enum
{
    STATE_ACTIVE,
    STATE_INACTIVE
}

enum
{
    FLAG_SELECT  = (1 << 0)
}

enum
{
    RADAR_DISABLED,
    RADAR_TERRORIST,
    RADAR_CT,
    RADAR_BOTH
}

enum _:MAIN_SETTINGS
{
    bool:SETTING_BUY_LOAD,
    bool:SETTING_BUY_DEFAULT,
    SETTING_BUY_RADAR,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,

    Float:SETTING_SIZE_BASE,
    Float:SETTING_SIZE_HEIGHT_MIN,
    Float:SETTING_SIZE_HEIGHT_MAX,
    Float:SETTING_SIZE_WIDTH_MIN,
    Float:SETTING_SIZE_WIDTH_MAX,

    SETTING_ICON[MAX_RESOURCE_PATH_LENGTH],
    bool:SETTING_ICON_SHOW,
    Float:SETTING_ICON_SCALE,
    SETTING_ICON_ALPHA,

    SETTING_BEAM,
    SETTING_COLOR_BEAM[3],
    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:BUY
{
    BUY_ID,
    BUY_STATE,
    BUY_FLAGS,
    BUY_ICON,
    Float:BUY_ORIGIN[3],
    Float:BUY_CORNERS[24],
    Float:BUY_MINS[3],
    Float:BUY_MAXS[3],
    Float:BUY_NEXT_RADAR
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_BUY_GHOST,
    PDATA_BUY_MENU,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,
    Float:PDATA_SIZE_X,
    Float:PDATA_SIZE_Y,
    Float:PDATA_SIZE_Z
}

enum
{
    MENU_ROOT,
    MENU_TOGGLE,
    MENU_REMOVE,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_TOGGLE,
    ROOT_REMOVE,
    ROOT_SAVE
}

enum
{
    TOGGLE_NEXT,
    TOGGLE_BACK,
    TOGGLE_CURRENT,
    TOGGLE_ALL_ON,
    TOGGLE_ALL_OFF
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,
    REMOVE_CURRENT,
    REMOVE_ALL
}

enum
{
    SCALE_HEIGHT_ADD,
    SCALE_HEIGHT_SUB,
    SCALE_WIDTH_ADD,
    SCALE_WIDTH_SUB,
    SCALE_PLACE
}

enum _:TASK_MENU
{
    TASK_ID,
    TASK_TYPE
}

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerToggle",
    "menuHandlerRemove",
    "menuHandlerScale"
}

new g_szCN[] = "BuyZone"

new Array:g_aBuy,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iBuy,
    g_iBombDrop,
    g_iHostagePos,
    g_iHostageK,
    g_iStatusIcon

public plugin_init()
{
    register_plugin("Buy Zone", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("buy", "cmdBuy")
    register_clcmd("say /bz",           "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /bz",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say /buyzone",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /buyzone", "cmdMenu", ADMIN_RCON)
    register_concmd("bz_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")
    register_concmd("buyzone_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("BuyZone.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    RegisterHam(Ham_Spawn, "func_buyzone", "fwdSpawn", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdIconSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_event("StatusIcon", "eventStatusIcon", "bef", "1=1", "2=buyzone")
    g_iBombDrop = get_user_msgid("BombDrop")
    g_iHostagePos = get_user_msgid("HostagePos")
    g_iHostageK = get_user_msgid("HostageK")
    g_iStatusIcon = get_user_msgid("StatusIcon")

    set_task(g_eSettings[SETTING_GHOST_FREQ], "buyTask", .flags = "b")

    if ( g_eSettings[SETTING_BUY_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aBuy = ArrayCreate(BUY)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBuy)
}

public cmdBuy(id)
{
    new eBuy[BUY]

    if ( isBuyActive(eBuy, id) ) return eBuy[BUY_STATE] != STATE_ACTIVE ? PLUGIN_HANDLED : PLUGIN_CONTINUE
    else                         return !g_eSettings[SETTING_BUY_DEFAULT] ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id
    iArg[TASK_TYPE] = MENU_ROOT

    set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_BUY_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1 ||
    equal(szCmd, "invnext") ||
    equal(szCmd, "invprev") ||
    equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

public eventStatusIcon(id)
{
    new eBuy[BUY]

    if ( isBuyActive(eBuy, id) ) iconDraw(id, eBuy[BUY_STATE] != STATE_ACTIVE ? false : true)
    else                         iconDraw(id, !g_eSettings[SETTING_BUY_DEFAULT] ? false : true)

    return PLUGIN_CONTINUE
}

ReadFile()
{
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/BuyZone.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        iSection = SECTION_NONE, iLine

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax( szData ), "[", "")
                    replace(szData, charsmax( szData ), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_BUY_LOAD") )
                        {
                            g_eSettings[SETTING_BUY_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BUY_DEFAULT") )
                        {
                            g_eSettings[SETTING_BUY_DEFAULT] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BUY_RADAR") )
                        {
                            g_eSettings[SETTING_BUY_RADAR] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_BASE") )
                        {
                            g_eSettings[SETTING_SIZE_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT_MIN") )
                        {
                            g_eSettings[SETTING_SIZE_HEIGHT_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT_MAX") )
                        {
                            g_eSettings[SETTING_SIZE_HEIGHT_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH_MIN") )
                        {
                            g_eSettings[SETTING_SIZE_WIDTH_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH_MAX") )
                        {
                            g_eSettings[SETTING_SIZE_WIDTH_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON") )
                        {
                            copy(g_eSettings[SETTING_ICON], charsmax(g_eSettings[SETTING_ICON]), szValue)
                            if ( !g_bFileWasRead ) precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_SHOW") )
                        {
                            g_eSettings[SETTING_ICON_SHOW] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_SCALE") )
                        {
                            g_eSettings[SETTING_ICON_SCALE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_ICON_ALPHA") )
                        {
                            g_eSettings[SETTING_ICON_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM") )
                        {
                            if ( !g_bFileWasRead ) g_eSettings[SETTING_BEAM] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_BEAM") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_BEAM][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_BEAM][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_BEAM][2] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_ACTIVE][2] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_INACTIVE][2] = str_to_num(szValue)
                        }
                    }
                }
            }
        }
    }

    if ( g_bFileWasRead )
    {
        new iPlayers[MAX_PLAYERS], iNum
        get_players(iPlayers, iNum, "ach")

        for ( new i = 0; i < iNum; i ++ )
            UpdateData(iPlayers[i])
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

    eventStatusIcon(id)
}

public buyMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex(szTitle,charsmax(szTitle), "%L", id, "BUY_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   menuRoot(id, iMenu)
        case MENU_TOGGLE: menuToggle(id, iMenu)
        case MENU_REMOVE: menuRemove(id, iMenu)
        case MENU_SCALE:  menuScale(id, iMenu)
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_TOGGLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_SAVE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iBuy >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_LIMIT")
            }
            else
            {
                buyCreate(id)

                iArg[TASK_TYPE] = MENU_SCALE
                set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_TOGGLE:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_TOGGLE
                set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_REMOVE
                set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuToggle(id, iMenu)
{
    new szItem[64],
        eBuy[BUY]

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_NEXT", g_ePlayerData[id][PDATA_BUY_MENU] == g_iBuy - 1 ? 1 : g_ePlayerData[id][PDATA_BUY_MENU] + 2)
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_BACK", g_ePlayerData[id][PDATA_BUY_MENU] == 0 ? g_iBuy : g_ePlayerData[id][PDATA_BUY_MENU])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L %L", id, "BUY_TOGGLE_CURRENT", id, eBuy[BUY_STATE] == STATE_ACTIVE ? "BUY_ON" : "BUY_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TOGGLE_ALL_ON")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TOGGLE_ALL_OFF")
    menu_additem(iMenu, szItem)

    eBuy[BUY_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerToggle(id, menu, item)
{
    new iArg[TASK_MENU],
        eBuy[BUY]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    switch( item )
    {
        case TOGGLE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] >= g_iBuy - 1 )
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BUY_MENU] ++

            iArg[TASK_TYPE] = MENU_TOGGLE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BUY_MENU] = g_iBuy - 1
            else
                g_ePlayerData[id][PDATA_BUY_MENU] --

            iArg[TASK_TYPE] = MENU_TOGGLE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_CURRENT:
        {
            eBuy[BUY_STATE] = eBuy[BUY_STATE] == STATE_ACTIVE ? STATE_INACTIVE : STATE_ACTIVE
            ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

            if ( g_eSettings[SETTING_ICON_SHOW] )
                iconColor(eBuy[BUY_ICON], eBuy[BUY_STATE] == STATE_ACTIVE ? true : false)

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_ALL_ON:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_STATE] = STATE_ACTIVE

                ArraySetArray(g_aBuy, i, eBuy)

                if ( g_eSettings[SETTING_ICON_SHOW] )
                    iconColor(eBuy[BUY_ICON], true)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case TOGGLE_ALL_OFF:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_STATE] = STATE_INACTIVE

                ArraySetArray(g_aBuy, i, eBuy)

                if ( g_eSettings[SETTING_ICON_SHOW] )
                    iconColor(eBuy[BUY_ICON], false)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_BUY_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eBuy[BUY]

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_NEXT", g_ePlayerData[id][PDATA_BUY_MENU] == g_iBuy - 1 ? 1 : g_ePlayerData[id][PDATA_BUY_MENU] + 2)
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_BACK", g_ePlayerData[id][PDATA_BUY_MENU] == 0 ? g_iBuy : g_ePlayerData[id][PDATA_BUY_MENU])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_CURRENT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    eBuy[BUY_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eBuy[BUY]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] >= g_iBuy - 1 )
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BUY_MENU] ++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BUY_MENU] = g_iBuy - 1
            else
                g_ePlayerData[id][PDATA_BUY_MENU] --

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_CURRENT:
        {
            buyKill(eBuy[BUY_ICON])
            buyKill(eBuy[BUY_ID])
            buyRemove(g_ePlayerData[id][PDATA_BUY_MENU])
            g_ePlayerData[id][PDATA_BUY_MENU] = 0

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case REMOVE_ALL:
        {
            while ( g_iBuy )
            {
                ArrayGetArray(g_aBuy, 0, eBuy)
                buyKill(eBuy[BUY_ICON])
                buyKill(eBuy[BUY_ID])

                buyRemove(0)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_BUY_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuScale(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_HEIGHT_ADD")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_HEIGHT_SUB")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_WIDTH_ADD")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_WIDTH_SUB")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerScale(id, menu, item)
{
    new eBuy[BUY], iItem,
        iArg[TASK_MENU]

    iItem = buyFind(g_ePlayerData[id][PDATA_BUY_GHOST], eBuy)
    iArg[TASK_ID] = id

    switch( item )
    {
        case SCALE_HEIGHT_ADD:
        {
            g_ePlayerData[id][PDATA_SIZE_Z] += 5.0

            if (g_ePlayerData[id][PDATA_SIZE_Z] > g_eSettings[SETTING_SIZE_HEIGHT_MAX])
                g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_HEIGHT_MAX]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_HEIGHT_SUB:
        {
            g_ePlayerData[id][PDATA_SIZE_Z] -= 5.0

            if (g_ePlayerData[id][PDATA_SIZE_Z] < g_eSettings[SETTING_SIZE_HEIGHT_MIN])
                g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_HEIGHT_MIN]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_WIDTH_ADD:
        {
            g_ePlayerData[id][PDATA_SIZE_X] += 5.0

            if (g_ePlayerData[id][PDATA_SIZE_X] > g_eSettings[SETTING_SIZE_WIDTH_MAX])
                g_ePlayerData[id][PDATA_SIZE_X] = g_eSettings[SETTING_SIZE_WIDTH_MAX]

            g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_X]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_WIDTH_SUB:
        {
            g_ePlayerData[id][PDATA_SIZE_X] -= 5.0

            if (g_ePlayerData[id][PDATA_SIZE_X] < g_eSettings[SETTING_SIZE_WIDTH_MIN])
                g_ePlayerData[id][PDATA_SIZE_X] = g_eSettings[SETTING_SIZE_WIDTH_MIN]

            g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_X]

            iArg[TASK_TYPE] = MENU_SCALE
            set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case SCALE_PLACE:
        {
            if ( iItem != -1 )
            {
                buyTrace(eBuy, id)

                g_ePlayerData[id][PDATA_BUY_GHOST] = 0
                pev(eBuy[BUY_ID], pev_origin, eBuy[BUY_ORIGIN])

                eBuy[BUY_STATE] = STATE_ACTIVE
                eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
                buySetActive(eBuy)
                ArraySetArray(g_aBuy, iItem, eBuy)

                iArg[TASK_TYPE] = MENU_ROOT
                set_task(MENU_BLINK, "buyMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        default:
        {
            buyKill(eBuy[BUY_ID])
            buyRemove(iItem)
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public buyTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eBuy[BUY], iEnt

    get_players(iPlayers, iNum, "ach")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iEnt = g_ePlayerData[id][PDATA_BUY_GHOST]

        if ( !iEnt || buyFind(iEnt, eBuy) == -1 )
            continue

        buyTrace(eBuy, id)
    }

    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)

        if ( eBuy[BUY_STATE] == STATE_ACTIVE
        && g_eSettings[SETTING_BUY_RADAR]
        && get_gametime() >= eBuy[BUY_NEXT_RADAR] )
            buyRadar(eBuy)

        if ( eBuy[BUY_FLAGS] & FLAG_SELECT )
            buyBeam(eBuy)

        ArraySetArray(g_aBuy, i, eBuy)
    }
}

stock iconCreate(Float:fOrigin[3])
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if ( !pev_valid(iEnt) )
        return 0

    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_origin, fOrigin)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_ICON])

    dllfunc(DLLFunc_Spawn, iEnt)
    return iEnt
}

stock buyCreate(id)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"))

    if ( !pev_valid(iEnt) )
        return

    new eBuy[BUY]
    set_pev(iEnt, pev_classname, g_szCN)

    if ( id )
    {
        g_ePlayerData[id][PDATA_BUY_GHOST] = iEnt
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
        g_ePlayerData[id][PDATA_SIZE_X] = g_ePlayerData[id][PDATA_SIZE_Y] = g_ePlayerData[id][PDATA_SIZE_Z] = g_eSettings[SETTING_SIZE_BASE]
    }

    eBuy[BUY_ID] = iEnt
    eBuy[BUY_STATE] = STATE_INACTIVE
    dllfunc(DLLFunc_Spawn, iEnt)

    ArrayPushArray(g_aBuy, eBuy)
    g_iBuy ++
}

public buyRemove(iItem)
{
    ArrayDeleteItem(g_aBuy, iItem)
    g_iBuy --
}

public iconDraw(id, bool:bDraw)
{
    message_begin(MSG_ONE_UNRELIABLE, g_iStatusIcon, .player = id)
    write_byte(bDraw ? 1 : 0)
    write_string("buyzone")
    write_byte(0)
    write_byte(120)
    write_byte(0)
    message_end()
}

public iconColor(id, bool:bActive)
{
    new iColor[3]

    if ( bActive ) for ( new i = 0; i < 3; i ++ ) iColor[i] = g_eSettings[SETTING_COLOR_ACTIVE][i]
    else           for ( new i = 0; i < 3; i ++ ) iColor[i] = g_eSettings[SETTING_COLOR_INACTIVE][i]

    set_rendering(id, kRenderNormal,
    iColor[0], iColor[1], iColor[2],
    kRenderTransAdd, g_eSettings[SETTING_ICON_ALPHA])
}

public saveData(id)
{
    new eBuy[BUY],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BuyZone.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "state = %d^n", eBuy[BUY_STATE])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eBuy[BUY_ORIGIN][0], eBuy[BUY_ORIGIN][1], eBuy[BUY_ORIGIN][2])
        fputs(iFile, szData)

        for ( new j = 0; j < 8; j ++ )
        {
            formatex(szData, charsmax(szData), "corner_%d = %.2f %.2f %.2f^n",
            j + 1, eBuy[BUY_CORNERS][j * 3], eBuy[BUY_CORNERS][j * 3 + 1], eBuy[BUY_CORNERS][j * 3 + 2])
            fputs(iFile, szData)
        }
    }

    client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_SAVED")
    fclose(iFile)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fCorners[8][3], iState,
        eBuy[BUY], iCorner, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BuyZone.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "BUY_CHAT_TAG", 0, "BUY_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                buyCreate(0)
                ArrayGetArray(g_aBuy, iCount, eBuy)

                eBuy[BUY_STATE] = iState
                eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
                xs_vec_copy(fOrigin, eBuy[BUY_ORIGIN])
                for ( new i = 0; i < 8; i ++ )
                    xs_vec_copy(fCorners[i], eBuy[BUY_CORNERS][i * 3])

                set_pev(eBuy[BUY_ID], pev_origin, fOrigin)
                buySetBox(eBuy, 0)
                buySetActive(eBuy)
                ArraySetArray(g_aBuy, iCount, eBuy)

                if ( eBuy[BUY_STATE] != STATE_ACTIVE )
                    iconColor(eBuy[BUY_ICON], false)
            }

            iCount++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 's':
                {
                    iState = str_to_num(szValue)
                }
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'c':
                {
                    iCorner = str_to_num(szKey[strlen(szKey) - 1])

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fCorners[iCorner - 1][0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fCorners[iCorner - 1][1] = str_to_float(szKey)
                    fCorners[iCorner - 1][2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        buyCreate(0)
        ArrayGetArray(g_aBuy, iCount, eBuy)

        eBuy[BUY_STATE] = iState
        eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
        xs_vec_copy(fOrigin, eBuy[BUY_ORIGIN])
        for ( new i = 0; i < 8; i ++ )
            xs_vec_copy(fCorners[i], eBuy[BUY_CORNERS][i * 3])

        set_pev(eBuy[BUY_ID], pev_origin, fOrigin)
        buySetBox(eBuy, 0)
        buySetActive(eBuy)
        ArraySetArray(g_aBuy, iCount, eBuy)

        if ( eBuy[BUY_STATE] != STATE_ACTIVE )
            iconColor(eBuy[BUY_ICON], false)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isBuyZone(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)

    return HAM_IGNORED
}

public fwdIconSpawn(iEnt)
{
    if ( !isBuyZone(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
    set_pev(iEnt, pev_scale, g_eSettings[SETTING_ICON_SCALE])
    set_rendering(iEnt, kRenderNormal,
    g_eSettings[SETTING_COLOR_ACTIVE][0], g_eSettings[SETTING_COLOR_ACTIVE][1], g_eSettings[SETTING_COLOR_ACTIVE][2],
    kRenderTransAdd, g_eSettings[SETTING_ICON_ALPHA])

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        new eBuy[BUY], iItem

        if ( (iItem = buyFind(g_ePlayerData[id][PDATA_BUY_GHOST], eBuy)) != -1 )
        {
            buyKill(eBuy[BUY_ID])
            buyRemove(iItem)
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0
        }
    }

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton
    iButton = pev(id, pev_button)

    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        if ( get_gametime() >= g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    return HAM_IGNORED
}

public buyTrace(eBuy[BUY], id)
{
    new Float:fVec1[3]

    pev(id, pev_origin, eBuy[BUY_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eBuy[BUY_ORIGIN], fVec1, eBuy[BUY_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eBuy[BUY_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eBuy[BUY_ORIGIN], fVec1, IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eBuy[BUY_ORIGIN])

    buySetBox(eBuy, id)
    buySetOffset(eBuy)
    buySetBox(eBuy, id)
    buyBeam(eBuy)

    set_pev(eBuy[BUY_ID], pev_origin, eBuy[BUY_ORIGIN])
}

stock buySetBox(eBuy[BUY], id)
{
    if ( id )
        boxCorners(eBuy, id)

    for ( new i = 0; i < 3; i ++ )
    {
        eBuy[BUY_MINS][i] = eBuy[BUY_CORNERS][i]
        eBuy[BUY_MAXS][i] = eBuy[BUY_CORNERS][i]
    }

    for ( new i = 1; i < 8; i ++ )
    {
        for ( new j = 0; j < 3; j ++ )
        {
            eBuy[BUY_MINS][j] = floatmin(eBuy[BUY_MINS][j], eBuy[BUY_CORNERS][i * 3 + j])
            eBuy[BUY_MAXS][j] = floatmax(eBuy[BUY_MAXS][j], eBuy[BUY_CORNERS][i * 3 + j])
        }
    }
}

public boxCorners(eBuy[BUY], id)
{
    eBuy[BUY_CORNERS][0]  = eBuy[BUY_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][1]  = eBuy[BUY_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][2]  = eBuy[BUY_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][3]  = eBuy[BUY_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][4]  = eBuy[BUY_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][5]  = eBuy[BUY_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][6]  = eBuy[BUY_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][7]  = eBuy[BUY_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][8]  = eBuy[BUY_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][9]  = eBuy[BUY_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][10] = eBuy[BUY_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][11] = eBuy[BUY_ORIGIN][2] - g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][12] = eBuy[BUY_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][13] = eBuy[BUY_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][14] = eBuy[BUY_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][15] = eBuy[BUY_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][16] = eBuy[BUY_ORIGIN][1] - g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][17] = eBuy[BUY_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][18] = eBuy[BUY_ORIGIN][0] - g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][19] = eBuy[BUY_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][20] = eBuy[BUY_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]

    eBuy[BUY_CORNERS][21] = eBuy[BUY_ORIGIN][0] + g_ePlayerData[id][PDATA_SIZE_X]
    eBuy[BUY_CORNERS][22] = eBuy[BUY_ORIGIN][1] + g_ePlayerData[id][PDATA_SIZE_Y]
    eBuy[BUY_CORNERS][23] = eBuy[BUY_ORIGIN][2] + g_ePlayerData[id][PDATA_SIZE_Z]
}

stock buySetOffset(eBuy[BUY])
{
    new Float:fVec1[3],
        Float:fGap, Float:fDist

    xs_vec_sub(eBuy[BUY_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
    engfunc(EngFunc_TraceLine, eBuy[BUY_ORIGIN], fVec1, IGNORE_MONSTERS, eBuy[BUY_ID], 0)
    get_tr2(0, TR_vecEndPos, fVec1)
    fDist = xs_vec_distance(eBuy[BUY_ORIGIN], fVec1)
    fGap = eBuy[BUY_ORIGIN][2] - eBuy[BUY_MINS][2]

    if ( fDist < (fGap + 1.0) )
    {
        get_tr2(0, TR_vecPlaneNormal, fVec1)
        xs_vec_mul_scalar(fVec1, (fGap + 1.0) - fDist, fVec1)
        xs_vec_add(eBuy[BUY_ORIGIN], fVec1, eBuy[BUY_ORIGIN])
    }
}

stock buySetActive(eBuy[BUY])
{
    new Float:fVec1[3],
        Float:fMins[3], Float:fMaxs[3]

    set_pev(eBuy[BUY_ID], pev_solid, SOLID_TRIGGER)
    set_pev(eBuy[BUY_ID], pev_movetype, MOVETYPE_NONE)
    xs_vec_sub(eBuy[BUY_MINS], eBuy[BUY_ORIGIN], fMins)
    xs_vec_sub(eBuy[BUY_MAXS], eBuy[BUY_ORIGIN], fMaxs)

    xs_vec_copy(eBuy[BUY_ORIGIN], fVec1)
    if ( g_eSettings[SETTING_ICON_SHOW] )
        eBuy[BUY_ICON] = iconCreate(fVec1)

    engfunc(EngFunc_SetSize, eBuy[BUY_ID], fMins, fMaxs)
}

stock buyBeam(eBuy[BUY])
{
    new Float:fCorners[8][3]

    xs_vec_copy(eBuy[BUY_CORNERS][0],  fCorners[0])
    xs_vec_copy(eBuy[BUY_CORNERS][3],  fCorners[1])
    xs_vec_copy(eBuy[BUY_CORNERS][6],  fCorners[2])
    xs_vec_copy(eBuy[BUY_CORNERS][9],  fCorners[3])
    xs_vec_copy(eBuy[BUY_CORNERS][12], fCorners[4])
    xs_vec_copy(eBuy[BUY_CORNERS][15], fCorners[5])
    xs_vec_copy(eBuy[BUY_CORNERS][18], fCorners[6])
    xs_vec_copy(eBuy[BUY_CORNERS][21], fCorners[7])

    beamDraw(fCorners[0], fCorners[1])
    beamDraw(fCorners[1], fCorners[3])
    beamDraw(fCorners[3], fCorners[2])
    beamDraw(fCorners[2], fCorners[0])

    beamDraw(fCorners[0], fCorners[4])
    beamDraw(fCorners[1], fCorners[5])
    beamDraw(fCorners[2], fCorners[6])
    beamDraw(fCorners[3], fCorners[7])

    beamDraw(fCorners[4], fCorners[5])
    beamDraw(fCorners[5], fCorners[7])
    beamDraw(fCorners[7], fCorners[6])
    beamDraw(fCorners[6], fCorners[4])
}

stock beamDraw(Float:fStart[3], Float:fEnd[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fStart)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(fStart[0])
    write_coord_f(fStart[1])
    write_coord_f(fStart[2])
    write_coord_f(fEnd[0])
    write_coord_f(fEnd[1])
    write_coord_f(fEnd[2])
    write_short(g_eSettings[SETTING_BEAM])
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(5)
    write_byte(0)
    write_byte(g_eSettings[SETTING_COLOR_BEAM][0])
    write_byte(g_eSettings[SETTING_COLOR_BEAM][1])
    write_byte(g_eSettings[SETTING_COLOR_BEAM][2])
    write_byte(255)
    write_byte(0)
    message_end()
}

stock buyRadar(eBuy[BUY])
{
    if ( g_eSettings[SETTING_BUY_RADAR] == RADAR_TERRORIST
    || g_eSettings[SETTING_BUY_RADAR] == RADAR_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iBombDrop)
        write_coord_f(eBuy[BUY_ORIGIN][0])
        write_coord_f(eBuy[BUY_ORIGIN][1])
        write_coord_f(eBuy[BUY_ORIGIN][2])
        write_byte(0)
        message_end()
    }

    if ( g_eSettings[SETTING_BUY_RADAR] == RADAR_CT
    || g_eSettings[SETTING_BUY_RADAR] == RADAR_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iHostageK)
        write_byte(0)
        message_end()

        message_begin(MSG_BROADCAST, g_iHostagePos)
        write_byte(0)
        write_byte(0)
        write_coord_f(eBuy[BUY_ORIGIN][0])
        write_coord_f(eBuy[BUY_ORIGIN][1])
        write_coord_f(eBuy[BUY_ORIGIN][2])
        message_end()
    }

    eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
}

stock bool:isBuyZone(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    return bool:equali(szEnt, g_szCN)
}

stock bool:isBuyActive(eBuy[BUY], id)
{
    new Float:fOrigin[3]

    pev(id, pev_origin, fOrigin)
    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)

        if ( fOrigin[0] >= eBuy[BUY_MINS][0] - 25.0 && fOrigin[0] <= eBuy[BUY_MAXS][0] + 25.0
        && fOrigin[1] >= eBuy[BUY_MINS][1] - 25.0 && fOrigin[1] <= eBuy[BUY_MAXS][1] + 25.0
        && fOrigin[2] >= eBuy[BUY_MINS][2] - 25.0 && fOrigin[2] <= eBuy[BUY_MAXS][2] + 25.0 )
            return true
    }

    return false
}

stock buyKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

public buyFind(iEnt, eBuy[BUY])
{
    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        if ( eBuy[BUY_ID] == iEnt )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}