/*
*
*	Buy Zone by RedSMURF
*
*
*	Description:
*       This plugin gives full control over buy zones, you can create, remove and toggle their status during game play.
*       It saves your custom buy zone setups/locations and automatically loads them every map start.
*       The plugin comes with a config file "configs/BuyZone.ini" to control some main settings
*       like whether or not to use default Buy Zones or Showing Buy Zones on the radar.
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
*       v1.1: Added independent axis scaling, mode toggle (Add/Remove), and factor control for precise box resizing,
*             Added noclip for players placing buy zones for easier positioning
*       v1.2: Bug fixes and config improvements.
*       v1.3: Added per-Buy Zone configuration.
*       v1.4: added FLAG_ACTIVE_DURATION, improved round-start logic.
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

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT                     32
#define ADMIN_ACCESS                ADMIN_RCON
#define BUY_KEY                     1824
#define BUY_ICON_KEY                4281
#define BUY_ICON_OWNER              pev_iuser1
#define BUY_ARRAY_ITEM              pev_iuser1
#define BUY_CHECK                   10.0
#define BUY_OFFSET_BASE             90.0
#define BUY_OFFSET_MIN              42.0
#define BUY_OFFSET_MAX              900.0
#define BUY_OFFSET_STEP             10.0
#define SIZE_BASE                   32.0
#define SIZE_HEIGHT_MIN             5.0
#define SIZE_HEIGHT_MAX             1500.0
#define SIZE_WIDTH_MIN              5.0
#define SIZE_WIDTH_MAX              1500.0
#define SIZE_DEPTH_MIN              5.0
#define SIZE_DEPTH_MAX              1500.0
#define PDATA_NEXT_ATTACK           83
#define XO_CBASEPLAYER              5
#define XO_CBASEPLAYERWEAPON        4
#define SOUND_NAV                   "buttons/blip1.wav"
#define SOUND_REMOVE                "buttons/button10.wav"
#define SOUND_ALERT                 "buttons/bell1.wav"
#define BEAM_WIDTH                  5
#define BEAM_ALPHA                  255
#define BEAM_SPRITE                 "sprites/white.spr"

new const PLUGIN_VERSION[]       = "1.5"
new const Float:DELAY_ON_LOAD    = 2.0
new const ERROR_FILE[]           = "BuyZone_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_BUY
}

enum
{
    DTYPE_INT,
    DTYPE_FLOAT,
    DTYPE_FLAGS,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_ARRAY_MESSAGE,
    DTYPE_ARRAY_MODEL,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL_ID,
    DTYPE_ARRAY_MODEL_ID
}

enum
{
    CLASS_BUYZONE,
    CLASS_BUYZONE_ICON
}

enum
{
    FLAG_ICON               = (1 << 0),

    FLAG_SELECT             = (1 << 1),
    FLAG_ACTIVE             = (1 << 2)
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_SPRITE_ICON[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_RADAR,
    SETTING_DEFAULT_TEAM,
    Float:SETTING_DEFAULT_ICON_SCALE,
    Float:SETTING_DEFAULT_ICON_ALPHA,

    bool:SETTING_BUY_LOAD,
    Float:SETTING_BUY_TASK,
    bool:SETTING_BUY_DEFAULT
}

enum _:BUY
{
    BUY_ID,
    BUY_ITEM,
    BUY_FLAGS,
    BUY_TEAM,
    BUY_RADAR,
    BUY_ICON,
    BUY_NAME[MAX_VALUE_LENGTH],

    Float:BUY_SCALE[3],
    Float:BUY_ORIGIN[3],
    Float:BUY_CORNERS[24],
    Float:BUY_MINS[3],
    Float:BUY_MAXS[3],
    Float:BUY_NEXT_RADAR
}

enum _:PLAYER_DATA
{
    PDATA_BUY_GHOST,
    PDATA_BUY_MENU,
    bool:PDATA_BUY_ACTION,
    bool:PDATA_BUY_ZONE,
    bool:PDATA_SCALE_UP,
    PDATA_SCALE_FACTOR,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_STATUS,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SCALE_HEIGHT,
    SCALE_WIDTH,
    SCALE_DEPTH,

    SCALE_FACTOR = 4,
    SCALE_MODE,
    SCALE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerStatus",
    "menuHandlerScale"
}

new Float:g_fScaleFactor[] = {5.0, 10.0, 20.0, 30.0, 45.0, 60.0}
new g_szCN[] = "buyzone"

new Array:g_aBuy,
    Array:g_aBuyConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false, g_iActivePlayers,
    HamHook:g_iFwdPreThink, HamHook:g_iFwdKilled,
    g_iBuy, g_iBuyConfig, g_iBeam,
    g_iBuyDrop, g_iHostagePos, g_iHostageK, g_iStatusIcon,
    g_iMaxPlayers

public plugin_init()
{
    register_plugin("Buy Zone", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_BuyZone", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("buy", "cmdBuy")
    register_clcmd("say /bz",           "cmdMenu", ADMIN_RCON, "-- Opens the Buy Zone menu.")
    register_clcmd("say_team /bz",      "cmdMenu", ADMIN_RCON, "-- Opens the Buy Zone menu.")
    register_clcmd("say /buyzone",      "cmdMenu", ADMIN_RCON, "-- Opens the Buy Zone menu.")
    register_clcmd("say_team /buyzone", "cmdMenu", ADMIN_RCON, "-- Opens the Buy Zone menu.")
    register_concmd("bz_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")
    register_concmd("buyzone_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("BuyZone.txt")

    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iFwdKilled = RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    register_event("StatusIcon", "eventStatusIconHide", "bef", "1=0", "2=buyzone")
    register_event("StatusIcon", "eventStatusIconDraw", "bef", "1=1", "2=buyzone")
    g_iBuyDrop = get_user_msgid("BombDrop")
    g_iHostagePos = get_user_msgid("HostagePos")
    g_iHostageK = get_user_msgid("HostageK")
    g_iStatusIcon = get_user_msgid("StatusIcon")
    g_iMaxPlayers = get_maxplayers()
    DisableForward()

    buyInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aBuy = ArrayCreate(BUY)
    g_aBuyConfig = ArrayCreate(BUY)
    g_iBeam = precache_model(BEAM_SPRITE)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBuy)
    ArrayDestroy(g_aBuyConfig)
}

public cmdBuy(id)
{
    new eBuy[BUY]

    if ( isBuyActive(eBuy, id) )
        return eBuy[BUY_FLAGS] & FLAG_ACTIVE && CsTeams:eBuy[BUY_TEAM] & cs_get_user_team(id) ? PLUGIN_CONTINUE : PLUGIN_HANDLED
    else
        return g_eSettings[SETTING_BUY_DEFAULT] ? PLUGIN_CONTINUE : PLUGIN_HANDLED
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)

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

public eventRoundStart()
{
    buyReset()
}

public eventStatusIconHide(id)
{
    g_ePlayerData[id][PDATA_BUY_ZONE] = false

    return PLUGIN_CONTINUE
}

public eventStatusIconDraw(id)
{
    new eBuy[BUY]

    g_ePlayerData[id][PDATA_BUY_ZONE] = true
    if ( isBuyActive(eBuy, id) ) iconDraw(id, eBuy[BUY_FLAGS] & FLAG_ACTIVE && CsTeams:eBuy[BUY_TEAM] & cs_get_user_team(id) ? true : false)
    else                         iconDraw(id, g_eSettings[SETTING_BUY_DEFAULT] ? true : false)

    return PLUGIN_CONTINUE
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        ArrayClear(g_aBuyConfig)
        g_iBuyConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
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
        eBuy[BUY], iSection = SECTION_NONE, iLine, iPos

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
                        continue
                    }
                    else
                    {
                        if ( g_iBuyConfig )
                            ArrayPushArray(g_aBuyConfig, eBuy)

                        copy(eBuy[BUY_NAME], charsmax(eBuy[BUY_NAME]), szData)
                        eBuy[BUY_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eBuy[BUY_TEAM]                = g_eSettings[SETTING_DEFAULT_TEAM]
                        eBuy[BUY_RADAR]               = g_eSettings[SETTING_DEFAULT_RADAR]

                        iSection = SECTION_BUY
                        g_iBuyConfig ++
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
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        iPos = contain(szValue, "#")
                        if ( iPos != -1 )
                            szValue[iPos] = EOS

                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_TEAM], charsmax(g_eSettings[SETTING_DEFAULT_TEAM]))
                        else if ( equali(szKey, "SETTING_DEFAULT_RADAR") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_RADAR], charsmax(g_eSettings[SETTING_DEFAULT_RADAR]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPRITE_ICON") )
                            parseSetting(DTYPE_STRING_MODEL, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPRITE_ICON], charsmax(g_eSettings[SETTING_DEFAULT_SPRITE_ICON]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_SCALE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ICON_SCALE], charsmax(g_eSettings[SETTING_DEFAULT_ICON_SCALE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_ALPHA") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ICON_ALPHA], charsmax(g_eSettings[SETTING_DEFAULT_ICON_ALPHA]))
                        else if ( equali(szKey, "SETTING_BUY_LOAD") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BUY_LOAD], charsmax(g_eSettings[SETTING_BUY_LOAD]))
                        else if ( equali(szKey, "SETTING_BUY_DEFAULT") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BUY_DEFAULT], charsmax(g_eSettings[SETTING_BUY_DEFAULT]))
                    }
                    case SECTION_BUY:
                    {
                        if ( equali(szKey, "BUY_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), eBuy[BUY_FLAGS], charsmax(eBuy[BUY_FLAGS]))
                        else if ( equali(szKey, "BUY_RADAR") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eBuy[BUY_RADAR], charsmax(eBuy[BUY_RADAR]))
                        else if ( equali(szKey, "BUY_TEAM") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), eBuy[BUY_TEAM], charsmax(eBuy[BUY_TEAM]))
                    }
                }
            }
        }
    }

    if ( g_iBuyConfig )
        ArrayPushArray(g_aBuyConfig, eBuy)
    else
        set_fail_state("No Buy Zones were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_disconnected(id)
{
    new eBuy[BUY], iItem
    if ( g_ePlayerData[id][PDATA_BUY_GHOST]
    && (iItem = buyGet(eBuy, g_ePlayerData[id][PDATA_BUY_GHOST])) != -1 )
    {
        buyKill(eBuy)
        buyRemove(iItem)
    }

    g_ePlayerData[id][PDATA_BUY_GHOST]   = 0
    g_ePlayerData[id][PDATA_BUY_ACTION]  = false
    g_ePlayerData[id][PDATA_BUY_MENU]    = 0
}

public buyInit()
{
    if ( g_eSettings[SETTING_BUY_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

stock buyMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[256], iMenu
    formatex(szData, charsmax(szData), "%L", id, "BUY_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:         { menuRoot(id, iMenu); }
        case MENU_CREATE:       { menuCreate(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_CREATE"); }
        case MENU_EDIT:         { menuEdit(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_EDIT"); }
        case MENU_REMOVE:       { menuRemove(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_REMOVE"); }
        case MENU_STATUS:       { menuStatus(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_STATUS"); }
        case MENU_SCALE:        { menuScale(id, iMenu);         format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_SCALE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_NOCLIP", id, (pev(id, pev_movetype) == MOVETYPE_NOCLIP) ? "BUY_ON" : "BUY_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_GODMODE", id, (pev(id, pev_takedamage) == DAMAGE_NO) ? "BUY_ON" : "BUY_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iBuy >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_LIMIT", MAX_ENT)

                buySound(id, SOUND_MENU_REMOVE)
                buyMenu(id, MENU_ROOT)
            }
            else
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_CREATE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")

                buySound(id, SOUND_MENU_REMOVE)
                buyMenu(id, MENU_ROOT)
            }
            else
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_EDIT)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")

                buySound(id, SOUND_MENU_REMOVE)
                buyMenu(id, MENU_ROOT)
            }
            else
            {
                buySound(id, SOUND_MENU_REMOVE)
                buyMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            buyNoClip(id)
        }
        case ROOT_GODMODE:
        {
            buyGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(id, iMenu)
{
    new eBuy[BUY], szItem[64]

    for ( new i = 0; i < g_iBuyConfig; i ++ )
    {
        ArrayGetArray(g_aBuyConfig, i, eBuy)

        copy(szItem, charsmax(szItem), eBuy[BUY_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    else if ( item == MENU_EXIT )
    {
        buySound(id, SOUND_MENU_NAV)
        buyMenu(id, MENU_ROOT)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    buyCreate(id, item)
    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_SCALE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BUY_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_STATUS:
        {
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eBuy[BUY]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_CURRENT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    buySelect(eBuy, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerRemove(id, menu, item)
{
    new eBuy[BUY]
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        buySelect(eBuy, eBuy[BUY_FLAGS] & FLAG_ACTIVE ? TARGET_HIDE : TARGET_GHOST)
        ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    }

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] >= g_iBuy - 1 )
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BUY_MENU] ++

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BUY_MENU] = g_iBuy - 1
            else
                g_ePlayerData[id][PDATA_BUY_MENU] --

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE
            buyKill(eBuy)
            buyRemove(g_ePlayerData[id][PDATA_BUY_MENU])

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_REMOVE_CURRENT")
            g_ePlayerData[id][PDATA_BUY_MENU] = 0

            buySound(id, g_iBuy > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            buyMenu(id, g_iBuy > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iBuy )
            {
                ArrayGetArray(g_aBuy, 0, eBuy)
                eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE

                buyKill(eBuy)
                buyRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_BUY_MENU] = 0

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BUY_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eBuy[BUY]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_CURRENT", id, eBuy[BUY_FLAGS] & FLAG_ACTIVE ? "BUY_ENABLED" : "BUY_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    buySelect(eBuy, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerStatus(id, menu, item)
{
    new eBuy[BUY]
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        buySelect(eBuy, eBuy[BUY_FLAGS] & FLAG_ACTIVE ? TARGET_HIDE : TARGET_GHOST)
        ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    }

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] >= g_iBuy - 1 )
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BUY_MENU] ++

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BUY_MENU] = g_iBuy - 1
            else
                g_ePlayerData[id][PDATA_BUY_MENU] --

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            eBuy[BUY_FLAGS] ^= FLAG_ACTIVE
            iconColor(eBuy)

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_CURRENT",
            id, eBuy[BUY_FLAGS] & FLAG_ACTIVE ? "BUY_CHAT_ENABLED" : "BUY_CHAT_DISABLED")
            ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE
                iconColor(eBuy)

                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_ALL_ENABLED")
            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE
                iconColor(eBuy)

                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_ALL_DISABLED")
            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BUY_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuScale(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_HEIGHT", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BUY_ADD" : "BUY_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_WIDTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BUY_ADD" : "BUY_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_DEPTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BUY_ADD" : "BUY_REMOVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_FACTOR", g_ePlayerData[id][PDATA_SCALE_UP] ? "\y" : "\r", g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_MODE", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BUY_INCREASE" : "BUY_DECREASE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_SCALE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerScale(id, menu, item)
{
    new eBuy[BUY], iItem
    if ( (iItem = buyGet(eBuy, g_ePlayerData[id][PDATA_BUY_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case SCALE_HEIGHT:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBuy[BUY_SCALE][2] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][2] > SIZE_HEIGHT_MAX )
                        eBuy[BUY_SCALE][2] = SIZE_HEIGHT_MAX
                }
            else
            {
                eBuy[BUY_SCALE][2] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][2] < SIZE_HEIGHT_MIN )
                    eBuy[BUY_SCALE][2] = SIZE_HEIGHT_MIN
            }

            ArraySetArray(g_aBuy, iItem, eBuy)
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_SCALE)
        }
        case SCALE_WIDTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBuy[BUY_SCALE][0] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][0] > SIZE_WIDTH_MAX )
                    eBuy[BUY_SCALE][0] = SIZE_WIDTH_MAX
            }
            else
            {
                eBuy[BUY_SCALE][0] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][0] < SIZE_WIDTH_MIN )
                    eBuy[BUY_SCALE][0] = SIZE_WIDTH_MIN
            }

            ArraySetArray(g_aBuy, iItem, eBuy)
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_SCALE)
        }
        case SCALE_DEPTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBuy[BUY_SCALE][1] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][1] > SIZE_DEPTH_MAX )
                    eBuy[BUY_SCALE][1] = SIZE_DEPTH_MAX
            }
            else
            {
                eBuy[BUY_SCALE][1] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if ( eBuy[BUY_SCALE][1] < SIZE_DEPTH_MIN )
                    eBuy[BUY_SCALE][1] = SIZE_DEPTH_MIN
            }

            ArraySetArray(g_aBuy, iItem, eBuy)
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_SCALE)
        }
        case SCALE_FACTOR:
        {
            g_ePlayerData[id][PDATA_SCALE_FACTOR] += 1
            if ( g_ePlayerData[id][PDATA_SCALE_FACTOR] >= sizeof(g_fScaleFactor) )
                g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_SCALE)
        }
        case SCALE_MODE:
        {
            g_ePlayerData[id][PDATA_SCALE_UP] = !g_ePlayerData[id][PDATA_SCALE_UP]

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_SCALE)
        }
        case SCALE_PLACE:
        {
            buyTrace(eBuy, id)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0

            eBuy[BUY_FLAGS] |= FLAG_ACTIVE
            buySetSize(eBuy)
            ArraySetArray(g_aBuy, iItem, eBuy)

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_CREATE_NEW")
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            buyKill(eBuy)
            buyRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_ROOT)
        }
        default:
        {
            buyKill(eBuy)
            buyRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public buyTask()
{
    new eBuy[BUY]
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_BUY_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_BUY_ACTION] )
                buyCheck(id)
        }
        else if ( buyGet(eBuy, g_ePlayerData[id][PDATA_BUY_GHOST]) != -1 )
        {
            buyTrace(eBuy, id)
        }
    }

    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        if ( eBuy[BUY_FLAGS] & FLAG_SELECT )
            buyBeam(eBuy)
    }
}

public buyCreate(id, iItem)
{
    new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"))
    if ( !pev_valid(iEnt) )
        return

    new eBuy[BUY]
    ArrayGetArray(g_aBuyConfig, iItem, eBuy)

    eBuy[BUY_ID] = iEnt
    eBuy[BUY_ITEM] = iItem
    eBuy[BUY_SCALE][0] = eBuy[BUY_SCALE][1] = eBuy[BUY_SCALE][2] = SIZE_BASE
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_BUY_GHOST] = iEnt
        g_ePlayerData[id][PDATA_BUY_ACTION] = true
        g_ePlayerData[id][PDATA_SCALE_UP] = true
        g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0
        g_ePlayerData[id][PDATA_OFFSET] = BUY_OFFSET_BASE
    }

    buySelect(eBuy, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, BUY_KEY)
    set_pev(iEnt, BUY_ARRAY_ITEM, g_iBuy)
    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)

    ArrayPushArray(g_aBuy, eBuy)
    if ( ++ g_iBuy == 1 )
        set_task(g_eSettings[SETTING_BUY_TASK], "buyTask", BUY_KEY, .flags = "b")
}

stock iconCreate(eBuy[BUY])
{
    new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
    if ( !pev_valid(iEnt) )
        return 0

    eBuy[BUY_ICON] = iEnt
    set_pev(iEnt, pev_impulse, BUY_KEY)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_origin, eBuy[BUY_ORIGIN])
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_SPRITE_ICON])
    dllfunc(DLLFunc_Spawn, iEnt)

    iconColor(eBuy)
    set_pev(iEnt, pev_renderfx, kRenderFxNone)
    set_pev(iEnt, pev_rendermode, kRenderTransAdd)
    set_pev(iEnt, pev_renderamt, eBuy[BUY_FLAGS] & FLAG_ICON ? g_eSettings[SETTING_DEFAULT_ICON_ALPHA] : 0.0)
    set_pev(iEnt, pev_scale, g_eSettings[SETTING_DEFAULT_ICON_SCALE])

    return iEnt
}

stock buyRemove(iItem)
{
    new eBuy[BUY]
    ArrayDeleteItem(g_aBuy, iItem)

    if ( -- g_iBuy == 0 )
        remove_task(BUY_KEY)

    for ( new i = iItem; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        set_pev(eBuy[BUY_ID], BUY_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eBuy[BUY],
        szFile[128], iFile,
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

        formatex(szData, charsmax(szData), "item = %d^n", eBuy[BUY_ITEM])
        fputs(iFile, szData)

        eBuy[BUY_FLAGS] &= ~FLAG_SELECT
        formatex(szData, charsmax(szData), "flags = %d^n", eBuy[BUY_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "scale = %.2f %.2f %.2f^n",
        eBuy[BUY_SCALE][0], eBuy[BUY_SCALE][1], eBuy[BUY_SCALE][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eBuy[BUY_ORIGIN][0], eBuy[BUY_ORIGIN][1], eBuy[BUY_ORIGIN][2])
        fputs(iFile, szData)

        for ( new j = 0; j < 8; j ++ )
        {
            formatex(szData, charsmax(szData), "corner_%d = %.2f %.2f %.2f^n",
            j + 1, eBuy[BUY_CORNERS][j * 3], eBuy[BUY_CORNERS][(j * 3) + 1], eBuy[BUY_CORNERS][(j * 3) + 2])
            fputs(iFile, szData)
        }
    }

    client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_SAVE", szFile)
    fclose(iFile)

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        iItem, iFlags, Float:fScale[3], Float:fOrigin[3], Float:fCorners[24],
        iCorner, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BuyZone.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataBuy(fCorners, fScale, fOrigin, iItem, iFlags, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "scale") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[1] = str_to_float(szKey)
                fScale[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( contain(szKey, "corner") != -1 )
            {
                iCorner = str_to_num(szKey[7])

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3 + 1] = str_to_float(szKey)
                fCorners[(iCorner - 1) * 3 + 2] = str_to_float(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataBuy(fCorners, fScale, fOrigin, iItem, iFlags, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataBuy(Float:fCorners[24], Float:fScale[3], Float:fOrigin[3], iItem, iFlags, iCount)
{
    new eBuy[BUY]
    buyCreate(0, iItem)
    ArrayGetArray(g_aBuy, iCount, eBuy)

    eBuy[BUY_FLAGS] = iFlags
    eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
    xs_vec_copy(fScale, eBuy[BUY_SCALE])
    xs_vec_copy(fOrigin, eBuy[BUY_ORIGIN])
    for ( new i = 0; i < 24; i ++ )
        eBuy[BUY_CORNERS][i] = fCorners[i]

    buySetBox(eBuy)
    buySetSize(eBuy)
    ArraySetArray(g_aBuy, iCount, eBuy)
}

public buyNoClip(id)
{
    set_pev(id, pev_movetype, pev(id, pev_movetype) == MOVETYPE_NOCLIP ? MOVETYPE_WALK : MOVETYPE_NOCLIP)

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)
}

public buyGodMode(id)
{
    set_pev(id, pev_takedamage, pev(id, pev_takedamage) == DAMAGE_NO ? DAMAGE_AIM : DAMAGE_NO)

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)
}

public fwdKilled(id, iAttacker, bGib)
{
    g_ePlayerData[id][PDATA_BUY_ACTION] = false

    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        new eBuy[BUY], iItem

        if ( (iItem = buyGet(eBuy, g_ePlayerData[id][PDATA_BUY_GHOST])) != -1 )
        {
            buyKill(eBuy)
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

    new iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        if ( get_gametime() >= g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += BUY_OFFSET_STEP
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], BUY_OFFSET_MIN, BUY_OFFSET_MAX)
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= BUY_OFFSET_STEP
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], BUY_OFFSET_MIN, BUY_OFFSET_MAX)
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + 0.1
            }
        }

        set_pdata_float(id, PDATA_NEXT_ATTACK, fCurrentTime + 0.1, XO_CBASEPLAYER, XO_CBASEPLAYER)
        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    return HAM_IGNORED
}

public iconDraw(id, bool:bDraw)
{
    message_begin(MSG_ONE_UNRELIABLE, g_iStatusIcon, .player = id)
    write_byte(bDraw ? 1 : 0)
    write_string("buyzone")
    write_byte(0)
    write_byte(165)
    write_byte(0)
    message_end()
}

public iconColor(eBuy[BUY])
{
    new Float:fRenderColor[3]
    if ( eBuy[BUY_FLAGS] & FLAG_ACTIVE )    { fRenderColor[0] = 0.0;      fRenderColor[1] = 255.0; fRenderColor[2] = 0.0; }
    else                                    { fRenderColor[0] = 255.0;    fRenderColor[1] = 0.0;   fRenderColor[2] = 0.0; }

    set_pev(eBuy[BUY_ICON], pev_rendercolor, fRenderColor)
}

stock iconRefresh()
{
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( g_ePlayerData[id][PDATA_BUY_ZONE] )
            eventStatusIconDraw(id)
    }
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

    buySetBox(eBuy, true)
    buySetOffset(eBuy)
    buySetBox(eBuy, true)
    buyBeam(eBuy)

    set_pev(eBuy[BUY_ID], pev_origin, eBuy[BUY_ORIGIN])
}

stock buyCheck(id)
{
    new eBuy[BUY], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = BUY_CHECK
    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        xs_vec_sub(eBuy[BUY_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(eBuy[BUY_ID], pev_absmin, fMins)
        pev(eBuy[BUY_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_BUY_MENU] != iBest )
    {
        ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
        eBuy[BUY_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_BUY_MENU] = iBest
        buyMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock buySetBox(eBuy[BUY], bool:bSetCorners = false)
{
    if ( bSetCorners )
        boxCorners(eBuy)

    xs_vec_copy(eBuy[BUY_CORNERS][0], eBuy[BUY_MINS])
    xs_vec_copy(eBuy[BUY_CORNERS][0], eBuy[BUY_MAXS])
    for ( new i = 1; i < 8; i ++ )
    {
        for ( new j = 0; j < 3; j ++ )
        {
            eBuy[BUY_MINS][j] = floatmin(eBuy[BUY_MINS][j], eBuy[BUY_CORNERS][i * 3 + j])
            eBuy[BUY_MAXS][j] = floatmax(eBuy[BUY_MAXS][j], eBuy[BUY_CORNERS][i * 3 + j])
        }
    }

    xs_vec_sub(eBuy[BUY_MINS], eBuy[BUY_ORIGIN], eBuy[BUY_MINS])
    xs_vec_sub(eBuy[BUY_MAXS], eBuy[BUY_ORIGIN], eBuy[BUY_MAXS])
}

public boxCorners(eBuy[BUY])
{
    eBuy[BUY_CORNERS][0]  = eBuy[BUY_ORIGIN][0] - eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][1]  = eBuy[BUY_ORIGIN][1] - eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][2]  = eBuy[BUY_ORIGIN][2] - eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][3]  = eBuy[BUY_ORIGIN][0] + eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][4]  = eBuy[BUY_ORIGIN][1] - eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][5]  = eBuy[BUY_ORIGIN][2] - eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][6]  = eBuy[BUY_ORIGIN][0] - eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][7]  = eBuy[BUY_ORIGIN][1] + eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][8]  = eBuy[BUY_ORIGIN][2] - eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][9]  = eBuy[BUY_ORIGIN][0] + eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][10] = eBuy[BUY_ORIGIN][1] + eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][11] = eBuy[BUY_ORIGIN][2] - eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][12] = eBuy[BUY_ORIGIN][0] - eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][13] = eBuy[BUY_ORIGIN][1] - eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][14] = eBuy[BUY_ORIGIN][2] + eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][15] = eBuy[BUY_ORIGIN][0] + eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][16] = eBuy[BUY_ORIGIN][1] - eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][17] = eBuy[BUY_ORIGIN][2] + eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][18] = eBuy[BUY_ORIGIN][0] - eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][19] = eBuy[BUY_ORIGIN][1] + eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][20] = eBuy[BUY_ORIGIN][2] + eBuy[BUY_SCALE][2]

    eBuy[BUY_CORNERS][21] = eBuy[BUY_ORIGIN][0] + eBuy[BUY_SCALE][0]
    eBuy[BUY_CORNERS][22] = eBuy[BUY_ORIGIN][1] + eBuy[BUY_SCALE][1]
    eBuy[BUY_CORNERS][23] = eBuy[BUY_ORIGIN][2] + eBuy[BUY_SCALE][2]
}

stock buySetOffset(eBuy[BUY])
{
    new Float:fGaps[6], Float:fVec1[3], Float:fCurrentGap
    fGaps[0] = -eBuy[BUY_MINS][0]
    fGaps[1] = eBuy[BUY_MAXS][0]
    fGaps[2] = -eBuy[BUY_MINS][1]
    fGaps[3] = eBuy[BUY_MAXS][1]
    fGaps[4] = -eBuy[BUY_MINS][2]
    fGaps[5] = eBuy[BUY_MAXS][2]

    for ( new i = 5; i >= 0; i -- )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eBuy[BUY_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eBuy[BUY_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eBuy[BUY_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eBuy[BUY_ORIGIN], fVec1)

        if ( fCurrentGap < (fGaps[i] + 1.0) )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, (fGaps[i] + 1.0) - fCurrentGap, fVec1)
            xs_vec_add(eBuy[BUY_ORIGIN], fVec1, eBuy[BUY_ORIGIN])
        }
    }
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

    beamDraw(fCorners[0], fCorners[1], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[3], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[2], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[0], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[0], fCorners[4], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[5], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[6], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[7], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[4], fCorners[5], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[5], fCorners[7], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[7], fCorners[6], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[6], fCorners[4], eBuy[BUY_FLAGS] & FLAG_ACTIVE != 0)
}

stock beamDraw(Float:fStart[3], Float:fEnd[3], bool:bActive)
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fStart)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(fStart[0])
    write_coord_f(fStart[1])
    write_coord_f(fStart[2])
    write_coord_f(fEnd[0])
    write_coord_f(fEnd[1])
    write_coord_f(fEnd[2])
    write_short(g_iBeam)
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(BEAM_WIDTH)
    write_byte(0)
    if ( bActive )
    {
        write_byte(0)
        write_byte(255)
        write_byte(0)
    }
    else
    {
        write_byte(255)
        write_byte(0)
        write_byte(0)
    }
    write_byte(BEAM_ALPHA)
    write_byte(0)
    message_end()
}

stock buyRadar(eBuy[BUY])
{
    if ( eBuy[BUY_RADAR] == TEAM_T
    || eBuy[BUY_RADAR] == TEAM_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iBuyDrop)
        write_coord_f(eBuy[BUY_ORIGIN][0])
        write_coord_f(eBuy[BUY_ORIGIN][1])
        write_coord_f(eBuy[BUY_ORIGIN][2])
        write_byte(0)
        message_end()
    }

    if ( eBuy[BUY_RADAR] == TEAM_CT
    || eBuy[BUY_RADAR] == TEAM_BOTH )
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

stock buyReset()
{
    new eBuy[BUY]
    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        eBuy[BUY_NEXT_RADAR] = 0.0
        ArraySetArray(g_aBuy, i, eBuy)
    }
}

stock buySetSize(eBuy[BUY])
{
    buySelect(eBuy, TARGET_HIDE)
    engfunc(EngFunc_SetOrigin, eBuy[BUY_ID], eBuy[BUY_ORIGIN])
    set_pev(eBuy[BUY_ID], pev_solid, eBuy[BUY_FLAGS] & FLAG_ACTIVE ? SOLID_TRIGGER : SOLID_NOT)
    set_pev(eBuy[BUY_ID], pev_movetype, MOVETYPE_NONE)

    engfunc(EngFunc_SetSize, eBuy[BUY_ID], eBuy[BUY_MINS], eBuy[BUY_MAXS])
    iconCreate(eBuy)
}

stock buySelect(eBuy[BUY], iAction)
{
    new Float:fRenderAmt
    if ( iAction == TARGET_SELECT )
    {
        iconColor(eBuy)
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
        eBuy[BUY_FLAGS] |= FLAG_SELECT
    }
    else if ( iAction == TARGET_GHOST )
    {
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
    }
    else if ( iAction == TARGET_HIDE )
    {
        fRenderAmt = eBuy[BUY_FLAGS] & FLAG_ICON ? g_eSettings[SETTING_DEFAULT_ICON_ALPHA] : 0.0
        eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    }
    else if ( iAction == TARGET_CLEAR )
    {
        fRenderAmt = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
        eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    }

    set_pev(eBuy[BUY_ICON], pev_renderamt, fRenderAmt)
}

stock buySound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0, iPitch = PITCH_NORM)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), SOUND_ALERT)
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, iPitch)
}

stock bool:isBuyActive(eBuy[BUY], id)
{
    new Float:fOrigin[3], Float:fAbsMins[3], Float:fAbsMaxs[3]

    pev(id, pev_origin, fOrigin)
    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)
        xs_vec_add(eBuy[BUY_ORIGIN], eBuy[BUY_MINS], fAbsMins)
        xs_vec_add(eBuy[BUY_ORIGIN], eBuy[BUY_MAXS], fAbsMaxs)

        if ( fOrigin[0] >= fAbsMins[0] - 25.0 && fOrigin[0] <= fAbsMaxs[0] + 25.0
        && fOrigin[1] >= fAbsMins[1] - 25.0 && fOrigin[1] <= fAbsMaxs[1] + 25.0
        && fOrigin[2] >= fAbsMins[2] - 25.0 && fOrigin[2] <= fAbsMaxs[2] + 25.0 )
            return true
    }

    return false
}

stock buyGet(eBuy[BUY], iEnt)
{
    if ( !isBuy(iEnt) )
        return -1

    new iItem
    iItem = pev(iEnt, BUY_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iBuy )
        return -1

    ArrayGetArray(g_aBuy, iItem, eBuy)
    return iItem
}

stock bool:isBuy(iEnt)
{
    return pev(iEnt, pev_impulse) == BUY_KEY
}

stock buyKill(eBuy[BUY])
{
    if ( pev_valid(eBuy[BUY_ID]) )
        set_pev(eBuy[BUY_ID], pev_flags, pev(eBuy[BUY_ID], pev_flags) | FL_KILLME)

    if ( pev_valid(eBuy[BUY_ICON]) )
        set_pev(eBuy[BUY_ICON], pev_flags, pev(eBuy[BUY_ICON], pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_ARRAY_MESSAGE:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_MODEL:
        {
            if ( !g_bFileWasRead )
                precache_model(szValue)

            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
        case DTYPE_ARRAY_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                ArrayPushCell(aOutput[0], precache_model(szValue))
        }
    }
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_BUY_ACTION] )
    {
        new eBuy[BUY]
        for ( new i = 0; i < g_iBuy; i ++ )
        {
            ArrayGetArray(g_aBuy, i, eBuy)
            buySelect(eBuy, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_BUY_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_BUY_ACTION] )
    {
        new eBuy[BUY]
        for ( new i = 0; i < g_iBuy; i ++ )
        {
            ArrayGetArray(g_aBuy, i, eBuy)
            buySelect(eBuy, TARGET_HIDE)
            ArraySetArray(g_aBuy, i, eBuy)
        }

        g_ePlayerData[id][PDATA_BUY_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    EnableHamForward(g_iFwdPreThink)
    EnableHamForward(g_iFwdKilled)
}

stock DisableForward()
{
    DisableHamForward(g_iFwdPreThink)
    DisableHamForward(g_iFwdKilled)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}
