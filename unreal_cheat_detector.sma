// Внимание тестовая версия, на свой страх и страх использовать!
// Внимание тестовая версия, на свой страх и страх использовать!
// Внимание тестовая версия, на свой страх и страх использовать!

#include <amxmodx>
#include <amxmisc>



//#define DROP_AFTER_BAN
#define DETECT_NONSTEAM_FILTERED_CVARS

#if defined DETECT_NONSTEAM_FILTERED_CVARS || defined DROP_AFTER_BAN
#include <reapi>
#endif

// Отключает множественный детект
#define ONCE_DETECT

/*
   Этапы работы:

	1. Обнаружить значение квара g_sCurrentCvarForCheck[id]
	2. Проверить наличие протектора на g_sCurrentCvarForCheck[id]
	3. Проверить наличие протектора
	4. Выдать бан или предупреждение

!Внимание мой способ детекта читов полностью универсален!
!То есть этот способ можно использовать для обнаружение других читов если поменять квары на те что меняет чит!

*/


// Установите свои строки для банов (%d это userid игрока) или расскоментируйте нужные #define
// BAN_CMD_POSSIBLE_FAKE может давать ложные когда игрок играет с нонстим сборки в стим версию игры
// для отключения детекта BAN_CMD_POSSIBLE_FAKE можете закомментировать строку DETECT_NONSTEAM_FILTERED_CVARS

//#define BAN_CMD_DETECTED_FAKE "amx_ban 1000 #%d ^"%s HACK DETECTED[FAKE CVAR]^""
//#define BAN_CMD_POSSIBLE_FAKE "amx_ban 1000 #%d ^"%s HACK POSSIBLE DETECTED[FAKE CVAR]^""
//#define BAN_CMD_DETECTED "amx_ban 1000 #%d ^"%s HACK DETECTED^""
//#define BAN_CMD_POSSIBLE "amx_ban 1000 #%d ^"%s HACK DETECTED POSSIBLE^""

new const Plugin_sName[] = "Unreal Cheat Detector";
new const Plugin_sVersion[] = "3.3";
new const Plugin_sAuthor[] = "Karaulov";

// Квар по умолчанию host_limitlocal не защищен cl_filterstuffcmd и может изменяться
// так что если квар не изменяется то значит стоит байпас на детект, новая версия это учитывает
new g_sCvarName1[] = "host_limitlocal";
new g_sCheatName1[] = "HPP v6";
new g_bFiltered1 = false;

// Квар по умолчанию cl_righthand не защищен cl_filterstuffcmd и может изменяться
// так что если квар не изменяется то значит стоит байпас на детект, новая версия это учитывает
new g_sCvarName2[] = "cl_righthand";
new g_sCheatName2[] = "INTERIUM";
new g_bFiltered2 = true;

// Квар по умолчанию cl_lw защищен cl_filterstuffcmd
// Требуется дополнительная проверка наличия протектора cl_filterstuffcmd
// Возможно использовать для детекта нескольких читов
new g_sCvarName3[] = "cl_lw";
new g_sCheatName3[] = "GENERIC 1";
new g_bFiltered3 = true;

// Квар по умолчанию cl_lc защищен cl_filterstuffcmd
// Требуется дополнительная проверка наличия протектора cl_filterstuffcmd
// Возможно использовать для детекта нескольких читов
new g_sCvarName4[] = "cl_lc";
new g_sCheatName4[] = "GENERIC 2";
new g_bFiltered4 = true;

// Сюда вписать любой квар который считаете безопасным для изменения что бы не получить бан от раскруток за его модификацию
// Он должен восстанавливаться после рестарта, и не влиять на игровой процесс
// Он должен быть защищен cl_filterstuffcmd
new g_sTempServerCvar[] = "sv_lan_rate";

new g_sCheatNames[MAX_PLAYERS + 1][64];
new g_sCurrentCvarForCheck[MAX_PLAYERS + 1][64];
new g_sCvarName1Backup[MAX_PLAYERS + 1][64];
new g_sTempSVCvarBackup[MAX_PLAYERS + 1][64];
new g_bHasProtector[MAX_PLAYERS + 1] = {false,...};
new g_bInitialIsZero[MAX_PLAYERS + 1] = {false,...};
new g_bFiltered[MAX_PLAYERS + 1] = {true,...};

new rate_check_value = 99999;

public plugin_init()
{
	register_plugin(Plugin_sName, Plugin_sVersion, Plugin_sAuthor);
	register_cvar("unreal_cheat_detect", Plugin_sVersion, FCVAR_SERVER | FCVAR_SPONLY);
	rate_check_value = random_num(10001, 99999);
}

public client_putinserver(id)
{
	remove_task(id);

	if (is_user_bot(id) || is_user_hltv(id))
		return;

	// Запуск проверки в начале игры и где-нибудь через пару минут
	// на наличие hpp чита
	set_task(0.5, "init_hack_cvar1_check", id);
	new Float:fTask2 = random_float(100.0, 300.0);
	set_task(fTask2, "init_hack_cvar1_check", id);

	// запускаем проверку спустя 10 секунд после первой
	// что бы не было никаких коллизий
	fTask2 += 10.0;
	set_task(10.0, "init_hack_cvar2_check", id);
	set_task(fTask2, "init_hack_cvar2_check", id);

	// запускаем проверку спустя 10 секунд после первой
	// что бы не было никаких коллизий
	fTask2 += 10.0;
	set_task(20.0, "init_hack_cvar3_check", id);
	set_task(fTask2, "init_hack_cvar3_check", id);
	
	// запускаем проверку спустя 10 секунд после первой
	// что бы не было никаких коллизий
	fTask2 += 10.0;
	set_task(30.0, "init_hack_cvar4_check", id);
	set_task(fTask2, "init_hack_cvar4_check", id);
}

public client_disconnected(client)
{
	remove_task(client);
}

public init_hack_cvar1_check(id)
{
	if (!is_user_connected(id))
		return;

	copy(g_sCurrentCvarForCheck[id],charsmax(g_sCurrentCvarForCheck[]),g_sCvarName1);
	copy(g_sCheatNames[id],charsmax(g_sCheatNames[]),g_sCheatName1);

	g_bHasProtector[id] = false;
	g_bInitialIsZero[id] = false;
	g_bFiltered[id] = g_bFiltered1;

	if (!is_user_connected(id))
		return;
	// Запрашиваем значение квара g_sCurrentCvarForCheck
	query_client_cvar(id, g_sCurrentCvarForCheck[id], "check_detect_cvar_defaultvalue");
}

public init_hack_cvar2_check(id)
{
	if (!is_user_connected(id))
		return;

	copy(g_sCurrentCvarForCheck[id],charsmax(g_sCurrentCvarForCheck[]),g_sCvarName2);
	copy(g_sCheatNames[id],charsmax(g_sCheatNames[]),g_sCheatName2);

	g_bHasProtector[id] = false;
	g_bInitialIsZero[id] = false;
	g_bFiltered[id] = g_bFiltered2;

	// Запрашиваем значение квара g_sCurrentCvarForCheck
	query_client_cvar(id, g_sCurrentCvarForCheck[id], "check_detect_cvar_defaultvalue");
}

public init_hack_cvar3_check(id)
{
	if (!is_user_connected(id))
		return;

	copy(g_sCurrentCvarForCheck[id],charsmax(g_sCurrentCvarForCheck[]),g_sCvarName3);
	copy(g_sCheatNames[id],charsmax(g_sCheatNames[]),g_sCheatName3);

	g_bHasProtector[id] = false;
	g_bInitialIsZero[id] = false;
	g_bFiltered[id] = g_bFiltered3;

	// Запрашиваем значение квара g_sCurrentCvarForCheck
	query_client_cvar(id, g_sCurrentCvarForCheck[id], "check_detect_cvar_defaultvalue");
}

public init_hack_cvar4_check(id)
{
	if (!is_user_connected(id))
		return;

	copy(g_sCurrentCvarForCheck[id],charsmax(g_sCurrentCvarForCheck[]),g_sCvarName4);
	copy(g_sCheatNames[id],charsmax(g_sCheatNames[]),g_sCheatName4);

	g_bHasProtector[id] = false;
	g_bInitialIsZero[id] = false;
	g_bFiltered[id] = g_bFiltered4;

	// Запрашиваем значение квара g_sCurrentCvarForCheck
	query_client_cvar(id, g_sCurrentCvarForCheck[id], "check_detect_cvar_defaultvalue");
}

public check_detect_cvar_defaultvalue(id, const cvar[], const value[])
{
	if (!is_user_connected(id))
		return;
	// Если значение 1 то считай чит уже активирован
	// Если же значение 0 то мы на всякий случай тоже проверяем, вдруг читер решил нас обмануть
	// Сохраняем старое значение g_sCurrentCvarForCheck[id] что бы потом вернуть все назад :)

	//log_amx("id1 = %d, cvar = %s, value = %s", id, cvar, value);

	copy(g_sCvarName1Backup[id],charsmax(g_sCvarName1Backup[]),value);

	if(str_to_float(value) != 0.0)
	{
		WriteClientStuffText(id, "%s 0^n",g_sCurrentCvarForCheck[id]);
		WriteClientStuffText(id, "%s 0^n",g_sCurrentCvarForCheck[id]);
	}
	else 
	{
		WriteClientStuffText(id, "%s 1^n",g_sCurrentCvarForCheck[id]);
		WriteClientStuffText(id, "%s 1^n",g_sCurrentCvarForCheck[id]);
		g_bInitialIsZero[id] = true;
	}
	
	// Отложенный запуск проверки что бы чит успел сделать свои дела
	set_task(0.5,"check_detect_cvar_value_task",id)
}

// Отложенный запуск проверки что бы чит успел сделать свои дела
public check_detect_cvar_value_task(id)
{
	if (!is_user_connected(id))
		return;

	query_client_cvar(id, g_sCurrentCvarForCheck[id], "check_detect_cvar_value2");
}

public check_detect_cvar_value2(id, const cvar[], const value[])
{
	if (!is_user_connected(id))
		return;
	
	//log_amx("id2 = %d, cvar = %s, value = %s", id, cvar, value);

	// Восстановим назад значение квара g_sCurrentCvarForCheck[id]
	WriteClientStuffText(id, "%s %s^n",g_sCurrentCvarForCheck[id],g_sCvarName1Backup[id]);
	WriteClientStuffText(id, "%s %s^n",g_sCurrentCvarForCheck[id],g_sCvarName1Backup[id]);

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

	//log_amx("id3 = %d, cvar = %s, value = %s", id, cvar, value);

	// Сразу делаем обход ложного rate_check_value если вдруг совпадение
	if (str_to_float(value) == float(rate_check_value))
		rate_check_value -= 1;

	copy(g_sTempSVCvarBackup[id],charsmax(g_sTempSVCvarBackup[]),value);

	WriteClientStuffText(id, "%s %d^n",g_sTempServerCvar,rate_check_value);
	WriteClientStuffText(id, "%s %d^n",g_sTempServerCvar,rate_check_value);
	
	set_task(0.5,"check_protector_task",id)
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

	//log_amx("id4 = %d, cvar = %s, value = %s, prot = %i, zero = %i, filtered = %i", id, cvar, value, g_bHasProtector[id], g_bInitialIsZero[id], g_bFiltered[id]);

	// Восстановим назад значение квара g_sCurrentCvarForCheck[id]
	WriteClientStuffText(id, "%s %s^n",g_sTempServerCvar,g_sTempSVCvarBackup[id]);
	WriteClientStuffText(id, "%s %s^n",g_sTempServerCvar,g_sTempSVCvarBackup[id]);

	// Если значение 0, и имеется протектор, но на самом деле не имеется протектор то баним
	if (g_bHasProtector[id])
	{
		if (g_bInitialIsZero[id])
		{
			if (str_to_float(value) == float(rate_check_value))
			{
				// Если нет протектора на g_sTempServerCvar то...
				new username[33];
				get_user_name(id,username,charsmax(username));
				client_print_color(0, print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 использует чит ^1%s^3! (с фейк кваром)",username, g_sCheatNames[id]);
				log_amx("[CHEAT DETECTOR]: Игрок %s использует чит %s c фейк кваром, значение квара : %s!",username, g_sCheatNames[id], g_sCvarName1Backup[id]);
#if defined ONCE_DETECT
				remove_task(id);
#endif
#if defined BAN_CMD_DETECTED_FAKE
				server_cmd(BAN_CMD_DETECTED_FAKE, get_user_userid(id), g_sCheatNames[id]);
#if defined DROP_AFTER_BAN
				set_task(0.1, "drop_client_delayed", id);
#endif
#endif
			}
#if defined DETECT_NONSTEAM_FILTERED_CVARS
			else if (!g_bFiltered[id] && is_user_steam(id))
			{
				new username[33];
				get_user_name(id,username,charsmax(username));
				client_print_color(0, print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 возможно использует чит ^1%s^3! (с фейк кваром)",username, g_sCheatNames[id]);
				log_amx("[CHEAT DETECTOR]: Игрок возможно %s использует чит %s c фейк кваром, значение квара : %s!",username, g_sCheatNames[id], g_sCvarName1Backup[id]);
#if defined ONCE_DETECT
				remove_task(id);
#endif
#if defined BAN_CMD_DETECTED_FAKE
				server_cmd(BAN_CMD_POSSIBLE_FAKE, get_user_userid(id), g_sCheatNames[id]);
#if defined DROP_AFTER_BAN
				set_task(0.1, "drop_client_delayed", id);
#endif
#endif
			}
#endif
		}
	}
	else if (!g_bInitialIsZero[id])
	{
		if(str_to_float(value) == float(rate_check_value))
		{
			// Если нет протектора на g_sTempServerCvar то...
			new username[33];
			get_user_name(id,username,charsmax(username));
			client_print_color(0, print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 использует чит ^1%s^3!",username, g_sCheatNames[id]);
			log_amx("[CHEAT DETECTOR]: Игрок %s использует чит %s!",username, g_sCheatNames[id]);
#if defined ONCE_DETECT
			remove_task(id);
#endif
#if defined BAN_CMD_DETECTED_FAKE
			server_cmd(BAN_CMD_DETECTED, get_user_userid(id), g_sCheatNames[id]);
#if defined DROP_AFTER_BAN
			set_task(0.1, "drop_client_delayed", id);
#endif
#endif
		}
		else if (!g_bFiltered[id])
		{
			new username[33];
			get_user_name(id,username,charsmax(username));
			client_print_color(0,print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 возможно использует чит ^1%s^3!",username, g_sCheatNames[id]);
			log_amx("[CHEAT DETECTOR]: Игрок %s возможно использует чит %s![99%%]",username, g_sCheatNames[id]);
#if defined ONCE_DETECT
			remove_task(id);
#endif
#if defined BAN_CMD_DETECTED_FAKE
			server_cmd(BAN_CMD_POSSIBLE, get_user_userid(id), g_sCheatNames[id]);
#if defined DROP_AFTER_BAN
			set_task(0.1, "drop_client_delayed", id);
#endif
#endif
		}
	}
}
#if defined DROP_AFTER_BAN
public drop_client_delayed(id)
{
	if (is_user_connected(id))
    {
        static cheat[64];
        formatex(cheat, charsmax(cheat), "Cheat Detected: %s", g_sCheatNames[id]);
		rh_drop_client(id, cheat);
    }
}
#endif

stock WriteClientStuffText(const index, const message[], any:... )
{
	new buffer[ 256 ];
	new numArguments = numargs();
	
	if (numArguments == 2)
	{
		message_begin(MSG_ONE, SVC_STUFFTEXT, _, index)
		write_string(message)
		message_end()
	}
	else 
	{
		vformat( buffer, charsmax( buffer ), message, 3 );
		message_begin(MSG_ONE, SVC_STUFFTEXT, _, index)
		write_string(buffer)
		message_end()
	}
}