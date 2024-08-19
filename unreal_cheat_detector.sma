#include <amxmodx>
#include <amxmisc>


// Выбросить после бана
#define DROP_AFTER_BAN
// Обнаружить чит хпп с ложным кваром для Steam пользователей
//#define DETECT_STEAMONLY_UNSAFE_METHOD
// Писать обнаружения в чат
//#define SHOW_IN_CHAT
// Писать в лог пользователей которых нельзя проверить
//#define SHOW_PROTECTOR_IN_LOG
// Отключает множественный детект
#define ONCE_DETECT

#if defined DETECT_STEAMONLY_UNSAFE_METHOD || defined DROP_AFTER_BAN
#include <reapi>
#endif


// Введите строку бана. 
// Параметры [username] [ip] [steamid] [userid] [hackname]. Например "amx_offban [steamid] 1000". 

//#define BAN_CMD_DETECTED "amx_ban 1000 #[userid] ^"[hackname] HACK DETECTED^""

new const Plugin_sName[] = "Unreal Cheat Detector";
new const Plugin_sVersion[] = "1.4";
new const Plugin_sAuthor[] = "Karaulov";


// Квар по умолчанию host_limitlocal не защищен cl_filterstuffcmd и может изменяться
// так что если квар не изменяется то значит стоит байпас на детект, новая версия это учитывает
new g_sCvarName1[] = "host_limitlocal";
new g_sCheatName1[] = "HPP v6";
new g_bFiltered1 = false;

// Квар по умолчанию cl_righthand защищен cl_filterstuffcmd
// Требуется дополнительная проверка наличия протектора cl_filterstuffcmd
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
// Он должен восстанавливаться после рестарта, и не влиять на игровой процесс (на всякий случай)
// Он должен быть защищен cl_filterstuffcmd
// ЭТОТ КВАР ВОССТАНАВЛИВАЕТСЯ В СЛЕДУЮЩЕМ КАДРЕ :)
//new g_sTempServerCvar[] = "host_framerate"; false detect 'serverov' bad cs 16 build
new g_sTempServerCvar[] = "cl_dlmax";

new g_sUserIds[MAX_PLAYERS + 1][32];
new g_sUserNames[MAX_PLAYERS + 1][33];
new g_sUserIps[MAX_PLAYERS + 1][33];
new g_sUserAuths[MAX_PLAYERS + 1][64];
new g_sCheatNames[MAX_PLAYERS + 1][64];
new g_sCurrentCvarForCheck[MAX_PLAYERS + 1][64];
new g_sCvarName1Backup[MAX_PLAYERS + 1][64];
new g_sTempSVCvarBackup[MAX_PLAYERS + 1][64];

new g_bFiltered[MAX_PLAYERS + 1] = {true,...};

new rate_check_value = 99999;

public plugin_init()
{
	register_plugin(Plugin_sName, Plugin_sVersion, Plugin_sAuthor);
	register_cvar("unreal_cheat_detect", Plugin_sVersion, FCVAR_SERVER | FCVAR_SPONLY);
	rate_check_value = random_num(10001, 99999);
}

public client_connectex(id, const name[], const ip[], reason[128])
{   
	copy(g_sUserNames[id],charsmax(g_sUserNames[]), name);
	copy(g_sUserIps[id],charsmax(g_sUserIps[]), ip);
	strip_port(g_sUserIps[id], charsmax(g_sUserIps[]));
	g_sUserAuths[id][0] = EOS;
	g_sUserIds[id][0] = EOS;
}

public client_authorized(id, const authid[])
{
	copy(g_sUserAuths[id],charsmax(g_sUserAuths[]), authid);
}

public client_putinserver(id)
{
	remove_task(id);

	formatex(g_sUserIds[id], charsmax(g_sUserIds[]), "%d", get_user_userid(id));

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
	}
	
	// Отложенный запуск проверки что бы чит успел сделать свои дела
	set_task(0.11,"check_detect_cvar_value_task",id)
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

	if (equal(g_sCvarName1Backup[id], value))
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
	
	RequestFrame("check_protector_task",id);
}

public check_protector_task(id)
{
	if (!is_user_connected(id))
		return;

	set_task(0.01,"check_protector_task2",id)
}

public check_protector_task2(id)
{
	if (!is_user_connected(id))
		return;

	query_client_cvar(id, g_sTempServerCvar, "check_protector2");
}

public check_protector2(id, const cvar[], const value[])
{
	if (!is_user_connected(id))
		return;

	//log_amx("id4 = %d, cvar = %s, value = %s, filtered = %i", id, cvar, value, g_bFiltered[id]);

	// Восстановим назад значение квара g_sCurrentCvarForCheck[id]
	WriteClientStuffText(id, "%s %s^n",g_sTempServerCvar,g_sTempSVCvarBackup[id]);
	WriteClientStuffText(id, "%s %s^n",g_sTempServerCvar,g_sTempSVCvarBackup[id]);

	new username[33];
	get_user_name(id,username,charsmax(username));
	
	// Если значение 0, и имеется протектор, но на самом деле не имеется протектор то баним
	if(str_to_float(value) == float(rate_check_value))
	{
		// Если нет протектора на g_sTempServerCvar то...
#if defined SHOW_IN_CHAT
		client_print_color(0, print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 использует чит ^1%s^3!",username, g_sCheatNames[id]);
#endif
		log_to_file("unreal_cheat_detect.log", "[CHEAT DETECTOR]: Игрок %s использует чит %s!",username, g_sCheatNames[id]);
#if defined ONCE_DETECT
		remove_task(id);
#endif
#if defined BAN_CMD_DETECTED
		static banstr[256];
		copy(banstr,charsmax(banstr), BAN_CMD_DETECTED);
		replace_all(banstr,charsmax(banstr),"[username]",g_sUserNames[id]);
		replace_all(banstr,charsmax(banstr),"[ip]",g_sUserIps[id]);
		replace_all(banstr,charsmax(banstr),"[userid]",g_sUserIds[id]);
		replace_all(banstr,charsmax(banstr),"[hackname]",g_sCheatNames[id]);
		if (replace_all(banstr,charsmax(banstr),"[steamid]",g_sUserAuths[id]) > 0 && g_sUserAuths[id][0] == EOS)
		{
			log_to_file("unreal_cheat_detect.log","[ERROR] Invalid ban string: %s",banstr);
		}
		else 
		{
			server_cmd("%s", banstr);
			log_to_file("unreal_cheat_detect.log",banstr);
		}
#endif
#if defined DROP_AFTER_BAN
		set_task(0.1, "drop_client_delayed", id);
#endif
	}
#if defined DETECT_STEAMONLY_UNSAFE_METHOD
	else if (!g_bFiltered[id])
	{
		if (is_user_steam(id))
		{
#if defined SHOW_IN_CHAT
			client_print_color(0,print_team_red, "^4[CHEAT DETECTOR]^3: Игрок^1 %s^3 возможно использует чит ^1%s^3 для Steam!",username, g_sCheatNames[id]);
#endif
			log_to_file("unreal_cheat_detect.log", "[CHEAT DETECTOR]: Игрок %s с читом %s для Steam!(если играет с чистого клиента)",username, g_sCheatNames[id]);
#if defined ONCE_DETECT
			remove_task(id);
#endif
#if defined DROP_AFTER_BAN
			set_task(0.1, "drop_client_delayed", id);
#endif
		}
		else 
		{
#if defined SHOW_PROTECTOR_IN_LOG
			log_to_file("unreal_cheat_detect.log", "[CHEAT DETECTOR]: Игрок %s зашел с протектором (cl_filterstuffcmd или кастомный) не позволяющим определить наличие чита.",username);
#endif
			remove_task(id);
		}
	}
#endif
	else
	{
#if defined SHOW_PROTECTOR_IN_LOG
		log_to_file("unreal_cheat_detect.log", "[CHEAT DETECTOR]: Игрок %s зашел с протектором (cl_filterstuffcmd или кастомный) не позволяющим определить наличие чита.",username);
#endif
		remove_task(id);
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

stock strip_port(address[], length)
{
	for (new i = length - 1; i >= 0; i--)
	{
		if (address[i] == ':')
		{
			address[i] = EOS;
			return;
		}
	}
}