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

#define MAX_ENT             32
#define BUY_KEY             1824
#define BUY_ICON_KEY        4281
#define BUY_ICON_OWNER      pev_iuser1
#define BUY_ARRAY_ITEM      pev_iuser1

new const PLUGIN_VERSION[]       = "1.3"
new const Float:DELAY_ON_CONNECT = 1.0
new const ERROR_FILE[]           = "BuyZone_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_BUY
}

enum
{
    CLASS_BUYZONE,
    CLASS_BUYZONE_ICON
}

enum
{
    FLAG_RADAR          = (1 << 0),
    FLAG_ICON           = (1 << 1),
    FLAG_ACTIVE_DELAY   = (1 << 2),

    FLAG_SELECT         = (1 << 3),
    FLAG_ACTIVE         = (1 << 4)
}

enum
{
    STATUS_DEFAULT,
    STATUS_FORCE_ENABLE,
    STATUS_FORCE_DISABLE
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
    SOUND_MENU_ALERT,

    SOUND_ENABLED,
    SOUND_DISABLED
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_RADAR,
    SETTING_DEFAULT_TEAM,
    Float:SETTING_DEFAULT_ACTIVE_CHANCE,
    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],
    SETTING_DEFAULT_ICON[MAX_RESOURCE_PATH_LENGTH],
    Float:SETTING_DEFAULT_ICON_SCALE,
    SETTING_DEFAULT_ICON_ALPHA,

    bool:SETTING_BUY_LOAD,
    bool:SETTING_BUY_DEFAULT,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,

    Float:SETTING_SIZE_BASE,
    Float:SETTING_SIZE_HEIGHT[2],
    Float:SETTING_SIZE_WIDTH[2],
    Float:SETTING_SIZE_DEPTH[2],

    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],
    Array:SETTING_SOUND_SUITCHARGE,
    Array:SETTING_SOUND_BLIP2,

    SETTING_BEAM,
    SETTING_BEAM_WIDTH,
    SETTING_BEAM_ALPHA,
    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:BUY
{
    BUY_ID,
    BUY_ITEM,
    BUY_FLAGS,
    BUY_STATUS,
    BUY_TEAM,
    BUY_RADAR,
    Float:BUY_ACTIVE_CHANCE,
    Float:BUY_ACTIVE_DELAY[2],
    Float:BUY_ACTIVE_DURATION[2],
    Float:BUY_ACTIVE_COOLDOWN[2],

    BUY_ICON,
    Float:BUY_ICON_SCALE,
    BUY_ICON_ALPHA,
    BUY_ICON_SPRITE[MAX_RESOURCE_PATH_LENGTH],
    BUY_NAME[MAX_VALUE_LENGTH],

    Float:BUY_SCALE[3],
    Float:BUY_ORIGIN[3],
    Float:BUY_CORNERS[24],
    Float:BUY_MINS[3],
    Float:BUY_MAXS[3],
    Float:BUY_NEXT_RADAR,
    Float:BUY_NEXT_ENABLE,
    Float:BUY_NEXT_DISABLE
}

enum _:PLAYER_DATA
{
    PDATA_BUY_GHOST,
    PDATA_BUY_MENU,
    bool:PDATA_BUY_ZONE,
    bool:PDATA_SCALE_UP,
    PDATA_SCALE_FACTOR,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_STATUS,
    MENU_REMOVE,
    MENU_TEAM,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_STATUS,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE,

    ROOT_TEAM
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE,
    STATUS_ALL_DEFAULT
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
    TEAM_NEXT,
    TEAM_BACK,

    TEAM_CURRENT = 3,
    TEAM_ALL_NONE,
    TEAM_ALL_T,
    TEAM_ALL_CT,
    TEAM_ALL_BOTH
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

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerStatus",
    "menuHandlerRemove",
    "menuHandlerTeam",
    "menuHandlerScale"
}

new Float:g_fScaleFactor[] = {5.0, 10.0, 20.0, 30.0, 45.0, 60.0}
new g_szCN[][] = {"buyzone", "buyzone_icon"}

new Array:g_aBuy,
    Array:g_aBuyConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false,
    g_iBuy, g_iBuyConfig,
    g_iBombDrop, g_iHostagePos, g_iHostageK, g_iStatusIcon,
    g_iMaxPlayers

new g_szStatus[][] = {"BUY_DEFAULT", "BUY_ENABLED", "BUY_DISABLED"}
new g_szStatusChat[][] = {"BUY_CHAT_DEFAULT", "BUY_CHAT_ENABLED", "BUY_CHAT_DISABLED"}
new g_szStatusColor[][] = {"\d", "\y", "\r"}
new g_szTeam[][] = {"BUY_NONE", "BUY_T", "BUY_CT", "BUY_BOTH"}
new g_szTeamChat[][] = {"BUY_CHAT_NONE", "BUY_CHAT_T", "BUY_CHAT_CT", "BUY_CHAT_BOTH"}

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
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "func_buyzone", "fwdSpawn", 1)
    RegisterHam(Ham_Spawn, "env_sprite", "fwdSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_event("StatusIcon", "eventStatusIconHide", "bef", "1=0", "2=buyzone")
    register_event("StatusIcon", "eventStatusIconDraw", "bef", "1=1", "2=buyzone")
    g_iBombDrop = get_user_msgid("BombDrop")
    g_iHostagePos = get_user_msgid("HostagePos")
    g_iHostageK = get_user_msgid("HostageK")
    g_iStatusIcon = get_user_msgid("StatusIcon")
    g_iMaxPlayers = get_maxplayers()

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "buyTask", .flags = "b")
    buyInit()
}

public plugin_precache()
{
    g_aBuy = ArrayCreate(BUY)
    g_aBuyConfig = ArrayCreate(BUY)
    g_eSettings[SETTING_SOUND_SUITCHARGE] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BLIP2] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBuy)
    ArrayDestroy(g_aBuyConfig)
    ArrayDestroy(g_eSettings[SETTING_SOUND_SUITCHARGE])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BLIP2])
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

public eventRoundStart()
{
    if ( !g_iBuy )
        return PLUGIN_HANDLED

    new eBuy[BUY], Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)

        if ( eBuy[BUY_STATUS] != STATUS_DEFAULT )
            continue

        buyReset(eBuy)

        if ( eBuy[BUY_ACTIVE_CHANCE] >= random_float(0.0, 1.0) )
        {
            if ( eBuy[BUY_FLAGS] & FLAG_ACTIVE_DELAY )
                eBuy[BUY_NEXT_ENABLE] = fCurrentTime + random_float(eBuy[BUY_ACTIVE_DELAY][0], eBuy[BUY_ACTIVE_DELAY][1])
            else
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE
        }

        ArraySetArray(g_aBuy, i, eBuy)
    }

    return PLUGIN_HANDLED
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
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)

        ArrayClear(g_eSettings[SETTING_SOUND_SUITCHARGE])
        ArrayClear(g_eSettings[SETTING_SOUND_BLIP2])
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
                        copy(eBuy[BUY_ICON_SPRITE], charsmax(eBuy[BUY_ICON_SPRITE]), g_eSettings[SETTING_DEFAULT_ICON])
                        eBuy[BUY_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eBuy[BUY_TEAM]                = g_eSettings[SETTING_DEFAULT_TEAM]
                        eBuy[BUY_RADAR]               = g_eSettings[SETTING_DEFAULT_RADAR]
                        eBuy[BUY_ACTIVE_CHANCE]       = g_eSettings[SETTING_DEFAULT_ACTIVE_CHANCE]
                        eBuy[BUY_ACTIVE_DELAY][0]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                        eBuy[BUY_ACTIVE_DELAY][1]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        eBuy[BUY_ACTIVE_DURATION][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                        eBuy[BUY_ACTIVE_DURATION][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        eBuy[BUY_ACTIVE_COOLDOWN][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                        eBuy[BUY_ACTIVE_COOLDOWN][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]
                        eBuy[BUY_ICON_SCALE]          = g_eSettings[SETTING_DEFAULT_ICON_SCALE]
                        eBuy[BUY_ICON_ALPHA]          = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]

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
                        {
                            g_eSettings[SETTING_DEFAULT_FLAGS] = read_flags(szValue)
                            g_eSettings[SETTING_DEFAULT_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                        {
                            g_eSettings[SETTING_DEFAULT_TEAM] = str_to_num(szValue)
                            g_eSettings[SETTING_DEFAULT_TEAM] = clamp(g_eSettings[SETTING_DEFAULT_TEAM], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_RADAR") )
                        {
                            g_eSettings[SETTING_DEFAULT_RADAR] = str_to_num(szValue)
                            g_eSettings[SETTING_DEFAULT_RADAR] = clamp(g_eSettings[SETTING_DEFAULT_RADAR], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_CHANCE") )
                        {
                            g_eSettings[SETTING_DEFAULT_ACTIVE_CHANCE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DELAY") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0] = str_to_float(szKey)
                            g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DURATION") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0] = str_to_float(szKey)
                            g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_COOLDOWN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0] = str_to_float(szKey)
                            g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON") )
                        {
                            copy(g_eSettings[SETTING_DEFAULT_ICON], charsmax(g_eSettings[SETTING_DEFAULT_ICON]), szValue)
                            if ( !g_bFileWasRead ) precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_SCALE") )
                        {
                            g_eSettings[SETTING_DEFAULT_ICON_SCALE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_ICON_ALPHA") )
                        {
                            g_eSettings[SETTING_DEFAULT_ICON_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BUY_LOAD") )
                        {
                            g_eSettings[SETTING_BUY_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BUY_DEFAULT") )
                        {
                            g_eSettings[SETTING_BUY_DEFAULT] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_OFFSET][0] = str_to_float(szKey)
                            g_eSettings[SETTING_OFFSET][1] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_SIZE_HEIGHT][0] = str_to_float(szKey)
                            g_eSettings[SETTING_SIZE_HEIGHT][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_SIZE_WIDTH][0] = str_to_float(szKey)
                            g_eSettings[SETTING_SIZE_WIDTH][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SIZE_DEPTH") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_SIZE_DEPTH][0] = str_to_float(szKey)
                            g_eSettings[SETTING_SIZE_DEPTH][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SUITCHARGE") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_SUITCHARGE], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BLIP2") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BLIP2], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM") )
                        {
                            if ( !g_bFileWasRead ) g_eSettings[SETTING_BEAM] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM_WIDTH") )
                        {
                            g_eSettings[SETTING_BEAM_WIDTH] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BEAM_ALPHA") )
                        {
                            g_eSettings[SETTING_BEAM_ALPHA] = str_to_num(szValue)
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
                    case SECTION_BUY:
                    {
                        if ( equali(szKey, "BUY_FLAGS") )
                        {
                            eBuy[BUY_FLAGS] = read_flags(szValue)
                            eBuy[BUY_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "BUY_RADAR") )
                        {
                            eBuy[BUY_RADAR] = str_to_num(szValue)
                            eBuy[BUY_RADAR] = clamp(eBuy[BUY_RADAR], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "BUY_TEAM") )
                        {
                            eBuy[BUY_TEAM] = str_to_num(szValue)
                            eBuy[BUY_TEAM] = clamp(eBuy[BUY_TEAM], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "BUY_ACTIVE_CHANCE") )
                        {
                            eBuy[BUY_ACTIVE_CHANCE] = str_to_float(szValue)
                            if ( eBuy[BUY_ACTIVE_CHANCE] < 0.0 ) eBuy[BUY_ACTIVE_CHANCE] = g_eSettings[SETTING_DEFAULT_ACTIVE_CHANCE]
                        }
                        else if ( equali(szKey, "BUY_ACTIVE_DELAY") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eBuy[BUY_ACTIVE_DELAY][0] = str_to_float(szKey)
                            eBuy[BUY_ACTIVE_DELAY][1] = str_to_float(szValue)

                            if ( eBuy[BUY_ACTIVE_DELAY][0] < 0.0 ) eBuy[BUY_ACTIVE_DELAY][0] = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                            if ( eBuy[BUY_ACTIVE_DELAY][1] < 0.0 ) eBuy[BUY_ACTIVE_DELAY][1] = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        }
                        else if ( equali(szKey, "BUY_ACTIVE_DURATION") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eBuy[BUY_ACTIVE_DURATION][0] = str_to_float(szKey)
                            eBuy[BUY_ACTIVE_DURATION][1] = str_to_float(szValue)

                            if ( eBuy[BUY_ACTIVE_DURATION][0] < 0.0 ) eBuy[BUY_ACTIVE_DURATION][0] = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                            if ( eBuy[BUY_ACTIVE_DURATION][1] < 0.0 ) eBuy[BUY_ACTIVE_DURATION][1] = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        }
                        else if ( equali(szKey, "BUY_ACTIVE_COOLDOWN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eBuy[BUY_ACTIVE_COOLDOWN][0] = str_to_float(szKey)
                            eBuy[BUY_ACTIVE_COOLDOWN][1] = str_to_float(szValue)

                            if ( eBuy[BUY_ACTIVE_COOLDOWN][0] < 0.0 ) eBuy[BUY_ACTIVE_COOLDOWN][0] = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                            if ( eBuy[BUY_ACTIVE_COOLDOWN][1] < 0.0 ) eBuy[BUY_ACTIVE_COOLDOWN][1] = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]
                        }
                        else if ( equali(szKey, "BUY_ICON_SCALE") )
                        {
                            eBuy[BUY_ICON_SCALE] = str_to_float(szValue)
                            if ( eBuy[BUY_ICON_SCALE] < 0.0 ) eBuy[BUY_ICON_SCALE] = g_eSettings[SETTING_DEFAULT_ICON_SCALE]
                        }
                        else if ( equali(szKey, "BUY_ICON_ALPHA") )
                        {
                            eBuy[BUY_ICON_ALPHA] = str_to_num(szValue)
                            if ( eBuy[BUY_ICON_ALPHA] < 0 ) eBuy[BUY_ICON_ALPHA] = g_eSettings[SETTING_DEFAULT_ICON_ALPHA]
                        }
                        else if ( equali(szKey, "BUY_ICON_SPRITE") )
                        {
                            copy(eBuy[BUY_ICON_SPRITE], charsmax(eBuy[BUY_ICON_SPRITE]), szValue)
                            if ( !g_bFileWasRead ) precache_model(szValue)
                        }
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

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    new iItem
    if ( g_ePlayerData[id][PDATA_BUY_GHOST]
    && (iItem = pev(g_ePlayerData[id][PDATA_BUY_GHOST], BUY_ARRAY_ITEM)) != -1 )
    {
        buyKill(g_ePlayerData[id][PDATA_BUY_GHOST])
        buyRemove(iItem)
    }

    g_ePlayerData[id][PDATA_BUY_GHOST]   = 0
    g_ePlayerData[id][PDATA_BUY_MENU]    = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public buyInit()
{
    if ( g_eSettings[SETTING_BUY_LOAD] )
        loadData()
}

public buyMenu(id, iType)
{
    new szData[64], iMenu
    formatex(szData, charsmax(szData), "%L", id, "BUY_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_CREATE"); }
        case MENU_STATUS: { menuStatus(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_STATUS"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_REMOVE"); }
        case MENU_TEAM:   { menuTeam(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_TEAM"); }
        case MENU_SCALE:  { menuScale(id, iMenu);   format(szData, charsmax(szData), "%s^n%L", szData, id, "BUY_ROOT_SCALE"); }
    }

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
    menu_additem(iMenu, szItem )

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_STATUS")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_NOCLIP", id, get_user_noclip(id) ? "BUY_ON" : "BUY_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_GODMODE", id, get_user_godmode(id) ? "BUY_ON" : "BUY_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_ROOT_TEAM")
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
            }
            else
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_CREATE)
            }
        }
        case ROOT_STATUS:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")
                buySound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_STATUS)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")
                buySound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                buySound(id, SOUND_MENU_REMOVE)
                buyMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_TEAM:
        {
            if ( !g_iBuy )
            {
                client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_NO_BUY")
                buySound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                buySound(id, SOUND_MENU_NAV)
                buyMenu(id, MENU_TEAM)
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
    new szItem[64]

    for ( new i = 0; i < g_iBuyConfig; i ++ )
    {
        new eBuy[BUY]
        ArrayGetArray(g_aBuyConfig, i, eBuy)

        copy(szItem, charsmax(szItem), eBuy[BUY_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( item == MENU_EXIT
    || !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    buyCreate(id, item)
    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_SCALE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eBuy[BUY]

    menuNav(id, iMenu)
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_CURRENT",
    g_szStatusColor[eBuy[BUY_STATUS]], eBuy[BUY_NAME], id, g_szStatus[eBuy[BUY_STATUS]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_STATUS_ALL_DEFAULT")
    menu_additem(iMenu, szItem)

    eBuy[BUY_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerStatus(id, menu, item)
{
    new eBuy[BUY]
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

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
            if ( ++ eBuy[BUY_STATUS] > STATUS_FORCE_DISABLE )
                eBuy[BUY_STATUS] = STATUS_DEFAULT

            if ( eBuy[BUY_STATUS] == STATUS_FORCE_ENABLE )
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE
            else if ( eBuy[BUY_STATUS] == STATUS_FORCE_DISABLE )
                eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_CURRENT",
            eBuy[BUY_NAME], id, g_szStatusChat[eBuy[BUY_STATUS]])
            ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

            iconRefresh()

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE
                eBuy[BUY_STATUS] = STATUS_FORCE_ENABLE

                ArraySetArray(g_aBuy, i, eBuy)
            }

            iconRefresh()

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
                eBuy[BUY_STATUS] = STATUS_FORCE_DISABLE

                ArraySetArray(g_aBuy, i, eBuy)
            }

            iconRefresh()

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_ALL_DISABLED")
            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_STATUS] = STATUS_DEFAULT
                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_STATUS_ALL_DEFAULT")
            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_STATUS)
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
    new eBuy[BUY], szItem[64]

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    menuNav(id, iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_CURRENT",
    g_szStatusColor[eBuy[BUY_STATUS]], eBuy[BUY_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    eBuy[BUY_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerRemove(id, menu, item)
{
    new eBuy[BUY]

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
            buyKill(eBuy[BUY_ICON])
            buyKill(eBuy[BUY_ID])
            buyRemove(g_ePlayerData[id][PDATA_BUY_MENU])

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_REMOVE_CURRENT", eBuy[BUY_NAME])
            g_ePlayerData[id][PDATA_BUY_MENU] = 0

            buySound(id, g_iBuy > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            buyMenu(id, g_iBuy > 0 ? MENU_REMOVE : MENU_ROOT)
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

            client_print_color(0, 0, "%L %L", 0, "BUY_CHAT_TAG", 0, "BUY_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_BUY_MENU] = 0

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_REMOVE)
        }
        default:
        {
            g_ePlayerData[id][PDATA_BUY_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuTeam(id, iMenu)
{
    new szItem[64], eBuy[BUY]

    menuNav(id, iMenu)
    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TEAM_CURRENT",
    eBuy[BUY_NAME], id, g_szTeam[eBuy[BUY_TEAM]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TEAM_ALL_NONE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TEAM_ALL_T")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TEAM_ALL_CT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BUY_TEAM_ALL_BOTH")
    menu_additem(iMenu, szItem)

    eBuy[BUY_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
}

public menuHandlerTeam(id, menu, item)
{
    new eBuy[BUY]

    ArrayGetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)
    eBuy[BUY_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

    switch( item )
    {
        case TEAM_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] >= g_iBuy - 1 )
                g_ePlayerData[id][PDATA_BUY_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BUY_MENU] ++

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BUY_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BUY_MENU] = g_iBuy - 1
            else
                g_ePlayerData[id][PDATA_BUY_MENU] --

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_CURRENT:
        {
            if ( ++ eBuy[BUY_TEAM] > TEAM_BOTH )
                eBuy[BUY_TEAM] = TEAM_NONE

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_TEAM_CURRENT",
            eBuy[BUY_NAME], id, g_szTeamChat[eBuy[BUY_TEAM]])
            ArraySetArray(g_aBuy, g_ePlayerData[id][PDATA_BUY_MENU], eBuy)

            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_NONE:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_TEAM] = TEAM_NONE
                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_TEAM_ALL_NONE")

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_T:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_TEAM] = TEAM_T
                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_TEAM_ALL_T")

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_CT:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_TEAM] = TEAM_CT
                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_TEAM_ALL_CT")

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_BOTH:
        {
            for ( new i = 0; i < g_iBuy; i ++ )
            {
                ArrayGetArray(g_aBuy, i, eBuy)
                eBuy[BUY_TEAM] = TEAM_BOTH
                ArraySetArray(g_aBuy, i, eBuy)
            }

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_TEAM_ALL_BOTH")

            buySound(id, SOUND_MENU_ALERT)
            buyMenu(id, MENU_TEAM)
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

    new Float:fCurrentTime
    fCurrentTime = get_gametime()

    switch( item )
    {
        case SCALE_HEIGHT:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBuy[BUY_SCALE][2] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBuy[BUY_SCALE][2] > g_eSettings[SETTING_SIZE_HEIGHT][1])
                    eBuy[BUY_SCALE][2] = g_eSettings[SETTING_SIZE_HEIGHT][1]
            }
            else
            {
                eBuy[BUY_SCALE][2] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBuy[BUY_SCALE][2] < g_eSettings[SETTING_SIZE_HEIGHT][0])
                    eBuy[BUY_SCALE][2] = g_eSettings[SETTING_SIZE_HEIGHT][0]
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
                if (eBuy[BUY_SCALE][0] > g_eSettings[SETTING_SIZE_WIDTH][1])
                    eBuy[BUY_SCALE][0] = g_eSettings[SETTING_SIZE_WIDTH][1]
            }
            else
            {
                eBuy[BUY_SCALE][0] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBuy[BUY_SCALE][0] < g_eSettings[SETTING_SIZE_WIDTH][0])
                    eBuy[BUY_SCALE][0] = g_eSettings[SETTING_SIZE_WIDTH][0]
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
                if (eBuy[BUY_SCALE][1] > g_eSettings[SETTING_SIZE_DEPTH][1])
                    eBuy[BUY_SCALE][1] = g_eSettings[SETTING_SIZE_DEPTH][1]
            }
            else
            {
                eBuy[BUY_SCALE][1] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBuy[BUY_SCALE][1] < g_eSettings[SETTING_SIZE_DEPTH][0])
                    eBuy[BUY_SCALE][1] = g_eSettings[SETTING_SIZE_DEPTH][0]
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
            g_ePlayerData[id][PDATA_BUY_GHOST] = 0

            if ( eBuy[BUY_FLAGS] & FLAG_ACTIVE_DELAY )
                eBuy[BUY_NEXT_ENABLE] = fCurrentTime + random_float(eBuy[BUY_ACTIVE_DELAY][0], eBuy[BUY_ACTIVE_DELAY][1])
            else
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE

            eBuy[BUY_NEXT_RADAR] = fCurrentTime + 2.0
            buySetActive(eBuy)
            ArraySetArray(g_aBuy, iItem, eBuy)

            client_print_color(id, id, "%L %L", id, "BUY_CHAT_TAG", id, "BUY_CHAT_CREATE_NEW", eBuy[BUY_NAME])
            buySound(id, SOUND_MENU_NAV)
            buyMenu(id, MENU_ROOT)
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
    new eBuy[BUY], iEnt, Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        iEnt = g_ePlayerData[id][PDATA_BUY_GHOST]

        if ( !iEnt || buyGet(eBuy, iEnt) == -1 )
            continue

        buyTrace(eBuy, id)
    }

    for ( new i = 0; i < g_iBuy; i ++ )
    {
        ArrayGetArray(g_aBuy, i, eBuy)

        if ( eBuy[BUY_FLAGS] & FLAG_SELECT )
            buyBeam(eBuy)

        if ( eBuy[BUY_FLAGS] & FLAG_ACTIVE )
        {
            if ( fCurrentTime >= eBuy[BUY_NEXT_RADAR] )
                buyRadar(eBuy)

            if ( eBuy[BUY_NEXT_DISABLE] > 0.0
            && fCurrentTime >= eBuy[BUY_NEXT_DISABLE] )
            {
                eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE
                eBuy[BUY_NEXT_DISABLE] = 0.0
                eBuy[BUY_NEXT_ENABLE] = fCurrentTime + random_float(eBuy[BUY_ACTIVE_COOLDOWN][0], eBuy[BUY_ACTIVE_COOLDOWN][1])
                ArraySetArray(g_aBuy, i, eBuy)

                iconRefresh()
                buySound(eBuy[BUY_ID], SOUND_DISABLED, .bPlayer = false)
            }
        }
        else
        {
            if ( eBuy[BUY_NEXT_ENABLE] > 0.0
            && fCurrentTime >= eBuy[BUY_NEXT_ENABLE] )
            {
                eBuy[BUY_FLAGS] |= FLAG_ACTIVE
                eBuy[BUY_NEXT_ENABLE] = 0.0
                eBuy[BUY_NEXT_DISABLE] = fCurrentTime + random_float(eBuy[BUY_ACTIVE_DURATION][0], eBuy[BUY_ACTIVE_DURATION][1])
                ArraySetArray(g_aBuy, i, eBuy)

                iconRefresh()
                buySound(eBuy[BUY_ID], SOUND_ENABLED, .bPlayer = false, .iPitch = 150)
            }
        }
    }
}

stock iconCreate(eBuy[BUY], Float:fOrigin[3])
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
    if ( !pev_valid(iEnt) )
        return 0

    new iColor[3]
    if ( eBuy[BUY_FLAGS] & FLAG_ACTIVE ) for ( new i = 0; i < 3; i ++ ) iColor[i] = g_eSettings[SETTING_COLOR_ACTIVE][i]
    else                                 for ( new i = 0; i < 3; i ++ ) iColor[i] = g_eSettings[SETTING_COLOR_INACTIVE][i]

    set_pev(iEnt, BUY_ICON_OWNER, eBuy[BUY_ID])
    set_pev(iEnt, pev_impulse, BUY_ICON_KEY)
    set_pev(iEnt, pev_classname, g_szCN[CLASS_BUYZONE_ICON])
    set_pev(iEnt, pev_origin, fOrigin)
    engfunc(EngFunc_SetModel, iEnt, eBuy[BUY_ICON_SPRITE])

    set_pev(iEnt, pev_scale, eBuy[BUY_ICON_SCALE])
    set_rendering(iEnt, kRenderNormal, iColor[0], iColor[1], iColor[2], kRenderTransAdd, eBuy[BUY_ICON_ALPHA])

    dllfunc(DLLFunc_Spawn, iEnt)
    return iEnt
}

public buyCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"))

    if ( !pev_valid(iEnt) )
        return;

    new eBuy[BUY]
    ArrayGetArray(g_aBuyConfig, iItem, eBuy)

    eBuy[BUY_ID] = iEnt
    eBuy[BUY_ITEM] = iItem
    eBuy[BUY_SCALE][0] = eBuy[BUY_SCALE][1] = eBuy[BUY_SCALE][2] = g_eSettings[SETTING_SIZE_BASE]
    if ( id )
    {
        g_ePlayerData[id][PDATA_BUY_GHOST] = iEnt
        g_ePlayerData[id][PDATA_SCALE_UP] = true
        g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
    }

    set_pev(iEnt, BUY_ARRAY_ITEM, g_iBuy)
    set_pev(iEnt, pev_impulse, BUY_KEY)
    set_pev(iEnt, pev_classname, g_szCN[CLASS_BUYZONE])

    ArrayPushArray(g_aBuy, eBuy)
    g_iBuy ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

stock buyRemove(iItem)
{
    new eBuy[BUY]
    ArrayDeleteItem(g_aBuy, iItem)
    g_iBuy --

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

        formatex(szData, charsmax(szData), "status = %d^n", eBuy[BUY_STATUS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "team = %d^n", eBuy[BUY_TEAM])
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
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        iItem, iFlags, iStatus, iTeam, Float:fScale[3], Float:fOrigin[3], Float:fCorners[24],
        iCorner, iCount = -1

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
                loadDataBuy(fCorners, fScale, fOrigin, iItem, iFlags, iStatus, iTeam, iCount)

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
            else if ( equal(szKey, "status") )
            {
                iStatus = str_to_num(szValue)
            }
            else if ( equal(szKey, "team") )
            {
                iTeam = str_to_num(szValue)
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
        loadDataBuy(fCorners, fScale, fOrigin, iItem, iFlags, iStatus, iTeam, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataBuy(Float:fCorners[24], Float:fScale[3], Float:fOrigin[3], iItem, iFlags, iStatus, iTeam, iCount)
{
    new eBuy[BUY]
    buyCreate(0, iItem)
    ArrayGetArray(g_aBuy, iCount, eBuy)

    eBuy[BUY_FLAGS] = iFlags
    eBuy[BUY_STATUS] = iStatus
    eBuy[BUY_TEAM] = iTeam
    eBuy[BUY_NEXT_RADAR] = get_gametime() + 2.0
    xs_vec_copy(fScale, eBuy[BUY_SCALE])
    xs_vec_copy(fOrigin, eBuy[BUY_ORIGIN])
    for ( new i = 0; i < 24; i ++ )
        eBuy[BUY_CORNERS][i] = fCorners[i]

    set_pev(eBuy[BUY_ID], pev_origin, fOrigin)
    buySetBox(eBuy)
    buySetActive(eBuy)
    ArraySetArray(g_aBuy, iCount, eBuy)
}

public buyNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)
}

public buyGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    buySound(id, SOUND_MENU_NAV)
    buyMenu(id, MENU_ROOT)
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

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isBuy(iEnt, CLASS_BUYZONE_ICON)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new eBuy[BUY], bool:bHidden
    if ( buyGet(eBuy, pev(iEnt, BUY_ICON_OWNER)) != -1
    && eBuy[BUY_FLAGS] & FLAG_ICON )
    {
        bHidden = !(eBuy[BUY_FLAGS] & FLAG_ACTIVE) || !(CsTeams:eBuy[BUY_TEAM] & cs_get_user_team(iHost))

        set_es(es, ES_RenderAmt, eBuy[BUY_ICON_ALPHA])
        if ( bHidden )
            set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])
        else
            set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isBuy(iEnt, CLASS_BUYZONE) && !isBuy(iEnt, CLASS_BUYZONE_ICON) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_BUY_GHOST] )
    {
        new eBuy[BUY], iItem

        if ( (iItem = buyGet(eBuy, g_ePlayerData[id][PDATA_BUY_GHOST])) != -1 )
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
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

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

stock buySetBox(eBuy[BUY], bool:bSetCorners = false)
{
    if ( bSetCorners )
        boxCorners(eBuy)

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
    if ( eBuy[BUY_FLAGS] & FLAG_ICON )
        eBuy[BUY_ICON] = iconCreate(eBuy, fVec1)

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
    write_short(g_eSettings[SETTING_BEAM])
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(5)
    write_byte(0)
    if ( bActive )
    {
        write_byte(g_eSettings[SETTING_COLOR_ACTIVE][0])
        write_byte(g_eSettings[SETTING_COLOR_ACTIVE][1])
        write_byte(g_eSettings[SETTING_COLOR_ACTIVE][2])
    }
    else
    {
        write_byte(g_eSettings[SETTING_COLOR_INACTIVE][0])
        write_byte(g_eSettings[SETTING_COLOR_INACTIVE][1])
        write_byte(g_eSettings[SETTING_COLOR_INACTIVE][2])
    }
    write_byte(255)
    write_byte(0)
    message_end()
}

stock buyRadar(eBuy[BUY])
{
    if ( eBuy[BUY_RADAR] == TEAM_T
    || eBuy[BUY_RADAR] == TEAM_BOTH )
    {
        message_begin(MSG_BROADCAST, g_iBombDrop)
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

stock buyReset(eBuy[BUY])
{
    eBuy[BUY_FLAGS] &= ~FLAG_ACTIVE
    eBuy[BUY_NEXT_RADAR] = 0.0
    eBuy[BUY_NEXT_ENABLE] = 0.0
    eBuy[BUY_NEXT_DISABLE] = 0.0
}

stock buySound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0, iPitch = PITCH_NORM)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
        case SOUND_ENABLED:     ArrayGetString(g_eSettings[SETTING_SOUND_SUITCHARGE],   random(ArraySize(g_eSettings[SETTING_SOUND_SUITCHARGE])),   szSample, charsmax(szSample))
        case SOUND_DISABLED:    ArrayGetString(g_eSettings[SETTING_SOUND_BLIP2],        random(ArraySize(g_eSettings[SETTING_SOUND_BLIP2])),        szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, iPitch)
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

stock buyGet(eBuy[BUY], iEnt)
{
    new iItem
    iItem = pev(iEnt, BUY_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iBuy )
        return -1

    ArrayGetArray(g_aBuy, iItem, eBuy)
    return iItem
}

stock bool:isBuy(iEnt, iClass)
{
    if ( iClass == CLASS_BUYZONE )
        return pev(iEnt, pev_impulse) == BUY_KEY
    else if ( iClass == CLASS_BUYZONE_ICON )
        return pev(iEnt, pev_impulse) == BUY_ICON_KEY

    return false
}

stock buyKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}