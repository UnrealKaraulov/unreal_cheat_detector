#include <amxmodx>
#include <amxmisc>
#include <reapi>

/*
   Этапы работы:

    1. Обнаружить значение квара g_sCvarName
    2. Проверить наличие протектора на g_sCvarName
    3. Проверить наличие протектора
    4. Выдать бан или предупреждение

!Внимание мой способ детекта читов полностью универсален!
!То есть этот способ можно использовать для обнаружение других читов если поменять квары на те что меняет чит!

*/

new const Plugin_sName[] = "Unreal HPPv6 Detector";
new const Plugin_sVersion[] = "2.0";
new const Plugin_sAuthor[] = "Karaulov";

// Квар по умолчанию host_limitlocal не защищен cl_filterstuffcmd и может изменяться
// так что если квар не изменяется то значит стоит байпас на детект, новая версия это учитывает
new g_sCvarName[] = "host_limitlocal";

// Сюда вписать любой квар который считаете безопасным для изменения что бы не получить бан от раскруток за его модификацию
// Он должен восстанавливаться после рестарта, и не влиять на игровой процесс
new g_sTempServerCvar[] = "sv_lan_rate";

new g_sCvarName1Backup[MAX_PLAYERS + 1][64];
new g_sTempSVCvarBackup[MAX_PLAYERS + 1][64];
new g_bHasProtector[MAX_PLAYERS + 1] = {false,...};
new g_bInitialIsZero[MAX_PLAYERS + 1] = {false,...};

new rate_check_value = 99999;

public plugin_init()
{
    register_plugin(Plugin_sName, Plugin_sVersion, Plugin_sAuthor);
    register_cvar("unreal_hppv6_detect", Plugin_sVersion, FCVAR_SERVER | FCVAR_SPONLY);

    rate_check_value = random_num(10001, 99999);
}

public client_putinserver(id)
{
    remove_task(id);

    g_bHasProtector[id] = false;
    g_bInitialIsZero[id] = false;

    // Запуск проверки в начале игры и где-нибудь через пару минут
    set_task(0.5, "init_hack_cvar_check", id);
    set_task(random_float(60.0, 300.0), "init_hack_cvar_check", id);
}

public client_disconnected(id)
{
    remove_task(id);
}

public init_hack_cvar_check(id)
{
    if (!is_user_connected(id))
        return;
    // Запрашиваем значение квара g_sCvarName
    query_client_cvar(id, g_sCvarName, "check_detect_cvar_defaultvalue");
}

public check_detect_cvar_defaultvalue(id, const cvar[], const value[])
{
    if (!is_user_connected(id))
        return;
    // Если значение 1 то считай чит уже активирован
    // Если же значение 0 то мы на всякий случай тоже проверяем, вдруг читер решил нас обмануть
    // Сохраняем старое значение g_sCvarName что бы потом вернуть все назад :)

    copy(g_sCvarName1Backup[id],charsmax(g_sCvarName1Backup[]),value);

    if(str_to_float(value) != 0.0)
    {
        client_cmd(id, "%s 0",g_sCvarName);
        client_cmd(id, "%s 0",g_sCvarName);
    }
    else 
    {
        client_cmd(id, "%s 1",g_sCvarName);
        client_cmd(id, "%s 1",g_sCvarName);
        g_bInitialIsZero[id] = true;
    }
    
    // Отложенный запуск проверки что бы чит успел сделать свои дела
    set_task(1.5,"check_detect_cvar_value_task",id)
}

// Отложенный запуск проверки что бы чит успел сделать свои дела
public check_detect_cvar_value_task(id)
{
    if (!is_user_connected(id))
        return;

    query_client_cvar(id, g_sCvarName, "check_detect_cvar_value2");
}

public check_detect_cvar_value2(id, const cvar[], const value[])
{
    if (!is_user_connected(id))
        return;
    
    // Восстановим назад значение квара g_sCvarName
    client_cmd(id, "%s %s",g_sCvarName,g_sCvarName1Backup[id]);
    client_cmd(id, "%s %s",g_sCvarName,g_sCvarName1Backup[id]);

    // Проверяевм значение, если 1 то считай чит уже активирован
    // Если же значение 0 то мы на всякий случай тоже проверяем, вдруг читер решил нас обмануть
    if(g_bInitialIsZero[id])
    {
        if (equal(g_sCvarName1Backup[id], value))
        {
            g_bHasProtector[id] = true;
            query_client_cvar(id, g_sTempServerCvar, "check_protector_default");
        }
    }
    else if (str_to_float(value) != 0.0)
    {
        query_client_cvar(id, g_sTempServerCvar, "check_protector_default");
    }
}

public check_protector_default(id, const cvar[], const value[])
{
    if (!is_user_connected(id))
        return;

    // Сразу делаем обход ложного rate_check_value если вдруг совпадение
    if (str_to_float(value) == float(rate_check_value))
        rate_check_value -= 1;

    copy(g_sTempSVCvarBackup[id],charsmax(g_sTempSVCvarBackup[]),value);

    client_cmd(id, "%s %d",g_sTempServerCvar,rate_check_value);
    client_cmd(id, "%s %d",g_sTempServerCvar,rate_check_value);
    
    set_task(1.5,"check_protector_task",id)
}

public check_protector_task(id)
{
    if (!is_user_connected(id))
        return;

    query_client_cvar(id, g_sTempServerCvar, "check_protector2");
}

public check_protector2(id, const cvar[], const value[])
{
    if (!is_user_connected(id))
        return;

    // Восстановим назад значение квара g_sCvarName
    client_cmd(id, "%s %s",g_sTempServerCvar,g_sTempSVCvarBackup[id]);
    client_cmd(id, "%s %s",g_sTempServerCvar,g_sTempSVCvarBackup[id]);

    // Если значение 0, и имеется протектор, но на самом деле не имеется протектор то баним
    if (g_bHasProtector[id])
    {
        if (g_bInitialIsZero[id])
        {
            if (str_to_float(value) == float(rate_check_value))
            {
                new username[33];
                get_user_name(id,username,charsmax(username));
                client_print_color(0, print_team_red, "^4[HPP DETECTOR]^3: Игрок^1 %s^3 использует ^1HPP HACK^3! (с фейк кваром)",username);
                log_amx("[HPP DETECTOR]: Игрок %s использует HPP HACK c фейк кваром[100%], значение квара : %s!",username, g_sCvarName1Backup[id]);
                //server_cmd("amx_ban 1000 #%d ^"HPP DETECTED[FAKE CVAR]^"", get_user_userid(id)); // Раскомментируйте строку для бана!
            }
            else 
            {
                new username[33];
                get_user_name(id,username,charsmax(username));
                client_print_color(0,print_team_red, "^4[HPP DETECTOR]^3: Игрок^1 %s^3 возможно использует ^1HPP HACK^3!",username);
                log_amx("[HPP DETECTOR]: Игрок %s возможно использует HPP HACK! [99%]",username);
                //server_cmd("amx_ban 1000 #%d ^"HPP DETECTED^"", get_user_userid(id));// Раскомментируйте строку для бана!
            }
        }
    }
    else if (!g_bInitialIsZero[id])
    {
        if(str_to_float(value) == float(rate_check_value))
        {
            new username[33];
            get_user_name(id,username,charsmax(username));
            client_print_color(0,print_team_red, "^4[HPP DETECTOR]^3: Игрок^1 %s^3 использует ^1HPP HACK^3!",username);
            log_amx("[HPP DETECTOR]: Игрок %s использует HPP HACK! [100%]",username);
            //server_cmd("amx_ban 1000 #%d ^"HPP DETECTED^"", get_user_userid(id)); // Раскомментируйте строку для бана!
        }
        else
        {
            new username[33];
            get_user_name(id,username,charsmax(username));
            client_print_color(0,print_team_red, "^4[HPP DETECTOR]^3: Игрок^1 %s^3 возможно использует ^1HPP HACK^3!",username);
            log_amx("[HPP DETECTOR]: Игрок %s возможно использует HPP HACK! [99%]",username);
            //server_cmd("amx_ban 1000 #%d ^"HPP DETECTED^"", get_user_userid(id));// Раскомментируйте строку для бана!
        }
    }
}