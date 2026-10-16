#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "Zombie Plague Banka Sistemi"
#define VERSION "1.1"
#define AUTHOR "Merhabalarr"

#define MAKS_CEPHANE 2000000000
#define BANK_DOSYASI "addons/amxmodx/configs/zp_bank/hesaplar.ini"

new g_iCephanePaketi[33];
new g_szBankaHesabi[33][32];
new g_szSifre[33][32];
new bool:g_bGirisYapildi[33];
new bool:g_bKayitOluyor[33];
new bool:g_bGirisYapiyor[33];
new g_iToplamYatirilan[33];
new g_iZombiOlmaSayisi[33];
new g_iHarcananCephane[33];

new bool:g_bGorevTamamlandi[33][6];
new bool:g_bGorevOduluAlindi[33][6];
new g_iGorevIlerleme[33][6];
new const g_szEtiket[] = "ServerNick";

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_dictionary("reapi_zpbanka.txt");

    register_clcmd("say /banka", "AnaMenuyuGoster");
    register_clcmd("say_team /banka", "AnaMenuyuGoster");
    register_clcmd("say /gorev", "GorevMenusunuGoster");
    register_clcmd("say_team /gorev", "GorevMenusunuGoster");
    register_clcmd("YatirMiktar", "YatirmaMiktariniIsle");
    register_clcmd("CekMiktar", "CekmeMiktariniIsle");
    register_clcmd("IsimGirisi", "IsimGirisiniIsle");
    register_clcmd("SifreGirisi", "SifreGirisiniIsle");
    register_clcmd("YeniSifre", "YeniSifreGirisiniIsle");

    register_event("HLTV", "YeniRound", "a", "1=0", "2=0");
    register_logevent("RoundSonu", 2, "1=Round_End");

    RegisterHam(Ham_Spawn, "player", "OyuncuDogdu", 1);

    register_menucmd(register_menuid("GirisMenusu"), (1<<0|1<<1|1<<9), "GirisMenusunuIsle");
    register_menucmd(register_menuid("BankaMenusu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<9), "BankaMenusunuIsle");
    register_menucmd(register_menuid("GorevMenusu"), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<9), "GorevMenusunuIsle");

    set_task(1.0, "CephaneHarcamaKontrol", _, _, _, "b");

    set_task(60.0, "OyunSuresiniKontrolEt", _, _, _, "b");

    new szDir[128];
    get_configsdir(szDir, charsmax(szDir));
    format(szDir, charsmax(szDir), "%s/zp_bank", szDir);

    if(!dir_exists(szDir))
        mkdir(szDir);
}

// Oyuncunun diline gore ceviri yapip sohbete basan yardimci fonksiyon
stock MesajGoster(const id, const szKey[], any:...)
{
    #pragma unused szKey
    new szMsg[192];
    vformat(szMsg, charsmax(szMsg), "%L", 1);
    client_print_color(id, print_team_blue, "^4[%s]^1 %s", g_szEtiket, szMsg);
}

public CephaneHarcamaKontrol()
{
    new players[32], num;
    get_players(players, num, "ach");

    for(new i = 0; i < num; i++)
    {
        new id = players[i];

        if(g_bGirisYapildi[id] && !g_bGorevTamamlandi[id][2])
        {
            new old_cephane = g_iHarcananCephane[id];
            new cephane = zp_get_user_ammo_packs(id);

            if(old_cephane > cephane)
            {
                new harcanan = old_cephane - cephane;
                g_iHarcananCephane[id] += harcanan;
                g_iGorevIlerleme[id][2] = g_iHarcananCephane[id];

                if(g_iHarcananCephane[id] >= 200)
                {
                    g_bGorevTamamlandi[id][2] = true;
                    g_bGorevOduluAlindi[id][2] = false;

                    new szTaskName[64];
                    format(szTaskName, charsmax(szTaskName), "%L", id, "TASK_NAME_2");
                    MesajGoster(id, "TASK_COMPLETE", szTaskName, 250);
                }
            }

            g_iHarcananCephane[id] = cephane;
        }
    }
}

public client_putinserver(id)
{
    if(is_user_connected(id))
    {
        g_iToplamYatirilan[id] = 0;
        g_iZombiOlmaSayisi[id] = 0;
        g_iHarcananCephane[id] = 0;

        for(new i = 0; i < 6; i++)
        {
            g_bGorevTamamlandi[id][i] = false;
            g_bGorevOduluAlindi[id][i] = false;
            g_iGorevIlerleme[id][i] = 0;
        }
    }
}

public client_authorized(id)
{
    if(!is_user_connected(id))
        return;

    new authid[32];
    get_user_authid(id, authid, charsmax(authid));

    new vaultkey[64], vaultdata[256];
    format(vaultkey, charsmax(vaultkey), "%s_BANKA", authid);

    if(get_vaultdata(vaultkey, vaultdata, charsmax(vaultdata)))
    {
        new hesap[32], sifre[32], cephane[10];
        parse(vaultdata, hesap, charsmax(hesap), sifre, charsmax(sifre), cephane, charsmax(cephane));

        copy(g_szBankaHesabi[id], charsmax(g_szBankaHesabi[]), hesap);
        copy(g_szSifre[id], charsmax(g_szSifre[]), sifre);
        g_iCephanePaketi[id] = str_to_num(cephane);
        g_bGirisYapildi[id] = true;

        if(!HesapDosyadaVarMi(g_szBankaHesabi[id]))
        {
            DosyayaHesapEkle(g_szBankaHesabi[id], g_szSifre[id], g_iCephanePaketi[id]);
        }

        MesajGoster(id, "LOGIN_SUCCESS", g_iCephanePaketi[id]);
    }
}

public client_disconnected(id)
{
    if(!is_user_connected(id))
        return;

    if(g_bGirisYapildi[id])
    {
        new cephane = zp_get_user_ammo_packs(id);
        if(cephane > 0)
        {
            if((g_iCephanePaketi[id] + cephane) > MAKS_CEPHANE)
            {
                g_iCephanePaketi[id] = MAKS_CEPHANE;
            }
            else
            {
                g_iCephanePaketi[id] += cephane;
            }

            zp_set_user_ammo_packs(id, 0);
            MesajGoster(id, "BANK_TRANSFER", cephane);
        }

        OyuncuVerisiniKaydet(id);
    }

    g_bGirisYapildi[id] = false;
    g_bKayitOluyor[id] = false;
    g_bGirisYapiyor[id] = false;
    g_iCephanePaketi[id] = 0;
    g_szBankaHesabi[id][0] = '^0';
    g_szSifre[id][0] = '^0';
}

public OyunSuresiniKontrolEt()
{
    new players[32], num;
    get_players(players, num, "ch");

    for(new i = 0; i < num; i++)
    {
        new id = players[i];

        if(!g_bGorevTamamlandi[id][0] && is_user_connected(id))
        {
            g_iGorevIlerleme[id][0]++;

            if(g_iGorevIlerleme[id][0] >= 25)
            {
                g_bGorevTamamlandi[id][0] = true;
                g_bGorevOduluAlindi[id][0] = false;

                new szTaskName[64];
                format(szTaskName, charsmax(szTaskName), "%L", id, "TASK_NAME_0");
                MesajGoster(id, "TASK_COMPLETE", szTaskName, 150);
            }
        }
    }
}

public RoundSonu()
{
    new players[32], num;
    get_players(players, num);

    for(new i = 0; i < num; i++)
    {
        new id = players[i];

        if(!g_bGorevTamamlandi[id][3])
        {
            g_iGorevIlerleme[id][3]++;

            if(g_iGorevIlerleme[id][3] >= 10)
            {
                g_bGorevTamamlandi[id][3] = true;
                g_bGorevOduluAlindi[id][3] = false;

                new szTaskName[64];
                format(szTaskName, charsmax(szTaskName), "%L", id, "TASK_NAME_3");
                MesajGoster(id, "TASK_COMPLETE", szTaskName, 75);
            }
        }
    }
}

public zp_user_infected_post(victim, attacker)
{
    if(!g_bGorevTamamlandi[victim][5])
    {
        g_iGorevIlerleme[victim][5]++;

        if(g_iGorevIlerleme[victim][5] >= 5)
        {
            g_bGorevTamamlandi[victim][5] = true;
            g_bGorevOduluAlindi[victim][5] = false;

            new szTaskName[64];
            format(szTaskName, charsmax(szTaskName), "%L", victim, "TASK_NAME_5");
            MesajGoster(victim, "TASK_COMPLETE", szTaskName, 50);
        }
    }
}

new const g_iGorevOdulleri[6] = { 150, 100, 250, 75, 125, 50 };
new const g_iGorevGereksinimleri[6] = { 25, 25, 200, 10, 500, 5 };

public GorevMenusunuGoster(id)
{
    static szMenu[640];
    new iUzunluk = 0;

    iUzunluk = format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "TASK_MENU_HEADER", g_szEtiket);

    for(new i = 0; i < 6; i++)
    {
        new szGorevAdi[64], szKey[16];
        formatex(szKey, charsmax(szKey), "TASK_NAME_%d", i);
        format(szGorevAdi, charsmax(szGorevAdi), "%L", id, szKey);

        new iGereksinim = g_iGorevGereksinimleri[i];
        new iOdul = g_iGorevOdulleri[i];

        if(g_bGorevTamamlandi[id][i])
        {
            if(g_bGorevOduluAlindi[id][i])
            {
                iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "TASK_REWARD_TAKEN", i+1, szGorevAdi);
            }
            else
            {
                iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "TASK_REWARD_AVAILABLE", i+1, szGorevAdi, iOdul);
            }
        }
        else
        {
            iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "TASK_PROGRESS_LINE", i+1, szGorevAdi, iOdul, g_iGorevIlerleme[id][i], iGereksinim);
        }
    }

    new szBack[32];
    format(szBack, charsmax(szBack), "%L", id, "ITEM_BACK");
    iUzunluk += copy(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, szBack);

    show_menu(id, (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<9), szMenu, -1, "GorevMenusu");
}

public GorevMenusunuIsle(id, tus)
{
    if(tus == 9)
    {
        if(g_bGirisYapildi[id])
            BankaMenusunuGoster(id);
        else
            show_menu(id, 0, "", 0);
        return PLUGIN_HANDLED;
    }

    if(tus < 0 || tus >= 6)
        return PLUGIN_HANDLED;

    new szGorevAdi[64], szKey[16], iOdul = g_iGorevOdulleri[tus];
    formatex(szKey, charsmax(szKey), "TASK_NAME_%d", tus);
    format(szGorevAdi, charsmax(szGorevAdi), "%L", id, szKey);

    if(!g_bGorevTamamlandi[id][tus])
    {
        new iGereksinim = g_iGorevGereksinimleri[tus];
        new iKalan = iGereksinim - g_iGorevIlerleme[id][tus];
        MesajGoster(id, "TASK_PROGRESS_MSG", szGorevAdi, g_iGorevIlerleme[id][tus], iGereksinim, iKalan);
    }
    else if(!g_bGorevOduluAlindi[id][tus])
    {
        new iYeniCephane = g_iCephanePaketi[id] + iOdul;

        if(iYeniCephane > MAKS_CEPHANE)
            iYeniCephane = MAKS_CEPHANE;

        g_iCephanePaketi[id] = iYeniCephane;
        g_bGorevOduluAlindi[id][tus] = true;
        MesajGoster(id, "TASK_REWARD_GIVEN", iOdul);
        OyuncuVerisiniKaydet(id);
    }

    GorevMenusunuGoster(id);
    return PLUGIN_HANDLED;
}

public AnaMenuyuGoster(id)
{
    if(!is_user_connected(id))
        return;

    if(!g_bGirisYapildi[id])
    {
        GirisMenusunuGoster(id);
        return;
    }

    BankaMenusunuGoster(id);
}

public GirisMenusunuGoster(id)
{
    if(!is_user_connected(id))
        return;

    static szMenu[512];
    new iUzunluk = 0;

    iUzunluk = format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "MENU_LOGIN_HEADER", g_szEtiket);
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_LOGIN");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_REGISTER");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_EXIT");

    show_menu(id, (1<<0|1<<1|1<<9), szMenu, -1, "GirisMenusu");
}

public GirisMenusunuIsle(id, tus)
{
    if(!is_user_connected(id))
        return PLUGIN_HANDLED;

    switch(tus)
    {
        case 0:
        {
            g_bGirisYapiyor[id] = true;
            g_bKayitOluyor[id] = false;
            client_cmd(id, "messagemode IsimGirisi");
        }
        case 1:
        {
            g_bKayitOluyor[id] = true;
            g_bGirisYapiyor[id] = false;
            client_cmd(id, "messagemode IsimGirisi");
        }
        case 9:
        {
            show_menu(id, 0, "", 0);
            return PLUGIN_HANDLED;
        }
    }
    return PLUGIN_HANDLED;
}

public BankaMenusunuGoster(id)
{
    if(!is_user_connected(id) || !g_bGirisYapildi[id])
    {
        if(is_user_connected(id))
            GirisMenusunuGoster(id);
        return;
    }

    static szMenu[512];
    new iUzunluk = 0;

    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "MENU_BANK_HEADER", g_szEtiket);
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_DEPOSIT_ONE");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_DEPOSIT_ALL");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_WITHDRAW_ONE");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_WITHDRAW_ALL");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_CHANGE_PASS");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_TASK_MENU");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_LOGOUT");
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "LABEL_ACCOUNT_NAME", g_szBankaHesabi[id]);
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "LABEL_BANK_AMMO", g_iCephanePaketi[id]);
    iUzunluk += format(szMenu[iUzunluk], charsmax(szMenu) - iUzunluk, "%L", id, "ITEM_BACK");

    show_menu(id, (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<9), szMenu, -1, "BankaMenusu");
}

public BankaMenusunuIsle(id, tus)
{
    if(!is_user_connected(id))
        return PLUGIN_HANDLED;

    switch(tus)
    {
        case 0:
        {
            client_cmd(id, "messagemode YatirMiktar");
        }
        case 1:
        {
            new iCephane = zp_get_user_ammo_packs(id);
            if(iCephane <= 0)
            {
                MesajGoster(id, "NO_DEPOSIT_AMMO");
                return PLUGIN_HANDLED;
            }

            if((g_iCephanePaketi[id] + iCephane) > MAKS_CEPHANE)
            {
                new iYatirilabilir = MAKS_CEPHANE - g_iCephanePaketi[id];
                g_iCephanePaketi[id] = MAKS_CEPHANE;
                zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) - iYatirilabilir);
                MesajGoster(id, "DEPOSIT_SUCCESS", iYatirilabilir);
            }
            else
            {
                g_iCephanePaketi[id] += iCephane;
                zp_set_user_ammo_packs(id, 0);
                MesajGoster(id, "DEPOSIT_SUCCESS", iCephane);

                if(!g_bGorevTamamlandi[id][4])
                {
                    g_iToplamYatirilan[id] += iCephane;
                    g_iGorevIlerleme[id][4] = g_iToplamYatirilan[id];

                    if(g_iGorevIlerleme[id][4] >= 500)
                    {
                        g_bGorevTamamlandi[id][4] = true;
                        g_bGorevOduluAlindi[id][4] = false;

                        new szTaskName[64];
                        format(szTaskName, charsmax(szTaskName), "%L", id, "TASK_NAME_4");
                        MesajGoster(id, "TASK_COMPLETE", szTaskName, 125);
                    }
                }
            }

            OyuncuVerisiniKaydet(id);
            BankaMenusunuGoster(id);
        }
        case 2:
        {
            client_cmd(id, "messagemode CekMiktar");
        }
        case 3:
        {
            if(g_iCephanePaketi[id] <= 0)
            {
                MesajGoster(id, "NO_WITHDRAW_AMMO");
                return PLUGIN_HANDLED;
            }

            zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + g_iCephanePaketi[id]);
            MesajGoster(id, "WITHDRAW_SUCCESS", g_iCephanePaketi[id]);
            g_iCephanePaketi[id] = 0;

            OyuncuVerisiniKaydet(id);
            BankaMenusunuGoster(id);
        }
        case 4:
        {
            client_cmd(id, "messagemode YeniSifre");
        }
        case 5:
        {
            GorevMenusunuGoster(id);
        }
        case 6:
        {
            g_bGirisYapildi[id] = false;
            g_szBankaHesabi[id][0] = '^0';
            g_szSifre[id][0] = '^0';
            g_iCephanePaketi[id] = 0;

            MesajGoster(id, "LOGGED_OUT");
            GirisMenusunuGoster(id);
        }
        case 9:
        {
            show_menu(id, 0, "", 0);
            return PLUGIN_HANDLED;
        }
    }
    return PLUGIN_HANDLED;
}

public YatirmaMiktariniIsle(id)
{
    if(!is_user_connected(id) || !g_bGirisYapildi[id])
        return PLUGIN_HANDLED;

    new szMiktar[32];
    read_args(szMiktar, charsmax(szMiktar));
    remove_quotes(szMiktar);
    trim(szMiktar);

    if(equal(szMiktar, ""))
    {
        MesajGoster(id, "ENTER_VALID_AMOUNT");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    new iMiktar = str_to_num(szMiktar);

    if(iMiktar <= 0)
    {
        MesajGoster(id, "ENTER_POSITIVE_AMOUNT");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    new iOyuncuCephane = zp_get_user_ammo_packs(id);

    if(iMiktar > iOyuncuCephane)
    {
        MesajGoster(id, "BANK_NOT_ENOUGH", iOyuncuCephane);
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    if((g_iCephanePaketi[id] + iMiktar) > MAKS_CEPHANE)
    {
        new iYatirilabilir = MAKS_CEPHANE - g_iCephanePaketi[id];
        g_iCephanePaketi[id] = MAKS_CEPHANE;
        zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) - iYatirilabilir);
        MesajGoster(id, "DEPOSIT_SUCCESS", iYatirilabilir);
    }
    else
    {
        g_iCephanePaketi[id] += iMiktar;
        zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) - iMiktar);
        MesajGoster(id, "DEPOSIT_SUCCESS", iMiktar);

        if(!g_bGorevTamamlandi[id][4])
        {
            g_iToplamYatirilan[id] += iMiktar;
            g_iGorevIlerleme[id][4] = g_iToplamYatirilan[id];

            if(g_iGorevIlerleme[id][4] >= 500)
            {
                g_bGorevTamamlandi[id][4] = true;
                g_bGorevOduluAlindi[id][4] = false;

                new szTaskName[64];
                format(szTaskName, charsmax(szTaskName), "%L", id, "TASK_NAME_4");
                MesajGoster(id, "TASK_COMPLETE", szTaskName, 125);
            }
        }
    }

    OyuncuVerisiniKaydet(id);
    BankaMenusunuGoster(id);
    return PLUGIN_HANDLED;
}

public CekmeMiktariniIsle(id)
{
    if(!is_user_connected(id) || !g_bGirisYapildi[id])
        return PLUGIN_HANDLED;

    new szMiktar[32];
    read_args(szMiktar, charsmax(szMiktar));
    remove_quotes(szMiktar);
    trim(szMiktar);

    if(equal(szMiktar, ""))
    {
        MesajGoster(id, "ENTER_VALID_AMOUNT");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    new iMiktar = str_to_num(szMiktar);

    if(iMiktar <= 0)
    {
        MesajGoster(id, "ENTER_POSITIVE_AMOUNT");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    if(iMiktar > g_iCephanePaketi[id])
    {
        MesajGoster(id, "BANK_NOT_ENOUGH", g_iCephanePaketi[id]);
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    g_iCephanePaketi[id] -= iMiktar;
    zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + iMiktar);

    MesajGoster(id, "WITHDRAW_SUCCESS", iMiktar);
    OyuncuVerisiniKaydet(id);
    BankaMenusunuGoster(id);
    return PLUGIN_HANDLED;
}

public IsimGirisiniIsle(id)
{
    if(!is_user_connected(id))
        return PLUGIN_HANDLED;

    new szIsim[32];
    read_args(szIsim, charsmax(szIsim));
    remove_quotes(szIsim);
    trim(szIsim);

    if(equal(szIsim, ""))
    {
        MesajGoster(id, "ENTER_VALID_ACCOUNT_NAME");

        if(g_bKayitOluyor[id])
            GirisMenusunuGoster(id);
        else if(g_bGirisYapiyor[id])
            GirisMenusunuGoster(id);

        return PLUGIN_HANDLED;
    }

    if(strlen(szIsim) < 3 || strlen(szIsim) > 20)
    {
        MesajGoster(id, "ACCOUNT_NAME_LENGTH");

        if(g_bKayitOluyor[id])
            GirisMenusunuGoster(id);
        else if(g_bGirisYapiyor[id])
            GirisMenusunuGoster(id);

        return PLUGIN_HANDLED;
    }

    if(g_bKayitOluyor[id])
    {
        if(HesapDosyadaVarMi(szIsim))
        {
            MesajGoster(id, "ACCOUNT_EXISTS");
            GirisMenusunuGoster(id);
            return PLUGIN_HANDLED;
        }

        copy(g_szBankaHesabi[id], charsmax(g_szBankaHesabi[]), szIsim);
        client_cmd(id, "messagemode SifreGirisi");
    }
    else if(g_bGirisYapiyor[id])
    {
        copy(g_szBankaHesabi[id], charsmax(g_szBankaHesabi[]), szIsim);
        client_cmd(id, "messagemode SifreGirisi");
    }

    return PLUGIN_HANDLED;
}

public SifreGirisiniIsle(id)
{
    if(!is_user_connected(id))
        return PLUGIN_HANDLED;

    new szSifre[32];
    read_args(szSifre, charsmax(szSifre));
    remove_quotes(szSifre);
    trim(szSifre);

    if(equal(szSifre, ""))
    {
        MesajGoster(id, "ENTER_VALID_PASSWORD");

        if(g_bKayitOluyor[id])
            GirisMenusunuGoster(id);
        else if(g_bGirisYapiyor[id])
            GirisMenusunuGoster(id);

        return PLUGIN_HANDLED;
    }

    if(strlen(szSifre) < 4 || strlen(szSifre) > 20)
    {
        MesajGoster(id, "PASSWORD_LENGTH");

        if(g_bKayitOluyor[id])
            GirisMenusunuGoster(id);
        else if(g_bGirisYapiyor[id])
            GirisMenusunuGoster(id);

        return PLUGIN_HANDLED;
    }

    if(g_bKayitOluyor[id])
    {
        copy(g_szSifre[id], charsmax(g_szSifre[]), szSifre);
        g_iCephanePaketi[id] = 0;
        g_bGirisYapildi[id] = true;

        DosyayaHesapEkle(g_szBankaHesabi[id], g_szSifre[id], g_iCephanePaketi[id]);
        OyuncuVerisiniKaydet(id);

        MesajGoster(id, "REGISTER_SUCCESS", g_szBankaHesabi[id], g_szSifre[id]);
        BankaMenusunuGoster(id);
    }
    else if(g_bGirisYapiyor[id])
    {
        if(!HesapDosyadaVarMi(g_szBankaHesabi[id]))
        {
            MesajGoster(id, "ACCOUNT_NOT_FOUND");
            GirisMenusunuGoster(id);
            return PLUGIN_HANDLED;
        }

        new iDosyaCephane;
        if(!DosyadanSifreKontrol(g_szBankaHesabi[id], szSifre, iDosyaCephane))
        {
            MesajGoster(id, "WRONG_PASSWORD");
            GirisMenusunuGoster(id);
            return PLUGIN_HANDLED;
        }

        copy(g_szSifre[id], charsmax(g_szSifre[]), szSifre);
        g_bGirisYapildi[id] = true;
        g_iCephanePaketi[id] = iDosyaCephane;

        OyuncuVerisiniKaydet(id);

        MesajGoster(id, "LOGIN_SUCCESS", g_iCephanePaketi[id]);
        BankaMenusunuGoster(id);
    }

    g_bKayitOluyor[id] = false;
    g_bGirisYapiyor[id] = false;

    return PLUGIN_HANDLED;
}

public YeniSifreGirisiniIsle(id)
{
    if(!is_user_connected(id) || !g_bGirisYapildi[id])
        return PLUGIN_HANDLED;

    new szYeniSifre[32];
    read_args(szYeniSifre, charsmax(szYeniSifre));
    remove_quotes(szYeniSifre);
    trim(szYeniSifre);

    if(equal(szYeniSifre, ""))
    {
        MesajGoster(id, "ENTER_VALID_PASSWORD");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    if(strlen(szYeniSifre) < 4 || strlen(szYeniSifre) > 20)
    {
        MesajGoster(id, "PASSWORD_LENGTH");
        BankaMenusunuGoster(id);
        return PLUGIN_HANDLED;
    }

    copy(g_szSifre[id], charsmax(g_szSifre[]), szYeniSifre);
    OyuncuVerisiniKaydet(id);

    MesajGoster(id, "PASSWORD_CHANGED", g_szSifre[id]);
    BankaMenusunuGoster(id);
    return PLUGIN_HANDLED;
}

bool:HesapDosyadaVarMi(const szHesap[])
{
    if(!file_exists(BANK_DOSYASI))
        return false;

    new szSatir[128], szMevcutHesap[32];
    new iDosya = fopen(BANK_DOSYASI, "rt");

    if(!iDosya)
        return false;

    while(!feof(iDosya))
    {
        fgets(iDosya, szSatir, charsmax(szSatir));
        trim(szSatir);

        if(contain(szSatir, "Nick [") == 0)
        {
            strtok(szSatir, szMevcutHesap, charsmax(szMevcutHesap), szSatir, charsmax(szSatir), ']');
            replace_string(szMevcutHesap, charsmax(szMevcutHesap), "Nick [", "");
            trim(szMevcutHesap);

            if(equal(szMevcutHesap, szHesap))
            {
                fclose(iDosya);
                return true;
            }
        }
    }

    fclose(iDosya);
    return false;
}

DosyayaHesapEkle(const szHesap[], const szSifre[], iCephane)
{
    if(!file_exists(BANK_DOSYASI))
    {
        write_file(BANK_DOSYASI, "; Banka Hesaplari^n", -1);
    }

    DosyadaHesabiGuncelle(szHesap, szSifre, iCephane);
}

bool:DosyadanSifreKontrol(const szHesap[], const szSifre[], &iCephane)
{
    if(!file_exists(BANK_DOSYASI))
        return false;

    new szSatir[128], szAnahtar[32], szDeger[32], szMevcutHesap[32];
    new iDosya = fopen(BANK_DOSYASI, "rt");
    new bool:bHesapBulundu = false;
    new bool:bSifreDogru = false;

    iCephane = 0;

    while(!feof(iDosya))
    {
        fgets(iDosya, szSatir, charsmax(szSatir));
        trim(szSatir);

        if(contain(szSatir, "Nick [") == 0)
        {
            strtok(szSatir, szMevcutHesap, charsmax(szMevcutHesap), szSatir, charsmax(szSatir), ']');
            replace_string(szMevcutHesap, charsmax(szMevcutHesap), "Nick [", "");
            trim(szMevcutHesap);

            if(equal(szMevcutHesap, szHesap))
            {
                bHesapBulundu = true;

                fgets(iDosya, szSatir, charsmax(szSatir));
                trim(szSatir);
                strtok(szSatir, szAnahtar, charsmax(szAnahtar), szDeger, charsmax(szDeger), '=');
                trim(szDeger);

                if(equal(szDeger, szSifre))
                {
                    bSifreDogru = true;
                }

                fgets(iDosya, szSatir, charsmax(szSatir));
                trim(szSatir);
                strtok(szSatir, szAnahtar, charsmax(szAnahtar), szDeger, charsmax(szDeger), '=');
                trim(szDeger);

                iCephane = max(0, str_to_num(szDeger));

                break;
            }
        }
    }

    fclose(iDosya);
    return (bHesapBulundu && bSifreDogru);
}

OyuncuVerisiniKaydet(id)
{
    if(!g_bGirisYapildi[id] || !is_user_connected(id))
        return;

    new authid[32];
    get_user_authid(id, authid, charsmax(authid));

    new vaultkey[64], vaultdata[256];
    format(vaultkey, charsmax(vaultkey), "%s_BANKA", authid);
    format(vaultdata, charsmax(vaultdata), "%s %s %d", g_szBankaHesabi[id], g_szSifre[id], g_iCephanePaketi[id]);

    set_vaultdata(vaultkey, vaultdata);

    DosyadaHesabiGuncelle(g_szBankaHesabi[id], g_szSifre[id], g_iCephanePaketi[id]);
}

DosyadaHesabiGuncelle(const szHesap[], const szSifre[], iCephane)
{
    new szGeciciDosya[128], szConfigsDir[64];
    get_configsdir(szConfigsDir, charsmax(szConfigsDir));
    formatex(szGeciciDosya, charsmax(szGeciciDosya), "%s/zp_bank/temp_bank.ini", szConfigsDir);

    new iDosya = fopen(BANK_DOSYASI, "rt");
    new iGeciciDosya = fopen(szGeciciDosya, "wt");

    if(!iGeciciDosya) {
        if(iDosya) fclose(iDosya);
        return;
    }

    new szSatir[128], szMevcutHesap[32], bool:bHesapBulundu = false;

    if(iDosya) {
        while(!feof(iDosya)) {
            if(!fgets(iDosya, szSatir, charsmax(szSatir))) continue;
            trim(szSatir);

            if(szSatir[0] == '^0') continue;

            if(szSatir[0] == ';') {
                continue;
            }

            if(contain(szSatir, "Nick [") == 0) {
                copy(szMevcutHesap, charsmax(szMevcutHesap), szSatir);
                replace_string(szMevcutHesap, charsmax(szMevcutHesap), "Nick [", "");
                replace_string(szMevcutHesap, charsmax(szMevcutHesap), "]", "");
                trim(szMevcutHesap);

                if(equal(szMevcutHesap, szHesap)) {
                    fprintf(iGeciciDosya, "Nick [%s]^nPassword = %s^nAmmoPacks = %d^n^n", szHesap, szSifre, iCephane);
                    bHesapBulundu = true;
                    fgets(iDosya, szSatir, charsmax(szSatir));
                    fgets(iDosya, szSatir, charsmax(szSatir));
                } else {
                    fprintf(iGeciciDosya, "Nick [%s]^n", szMevcutHesap);

                    fgets(iDosya, szSatir, charsmax(szSatir));
                    trim(szSatir);
                    fprintf(iGeciciDosya, "%s^n", szSatir);

                    fgets(iDosya, szSatir, charsmax(szSatir));
                    trim(szSatir);
                    fprintf(iGeciciDosya, "%s^n^n", szSatir);
                }
            }
        }
        fclose(iDosya);
    }

    if(!bHesapBulundu) {
        fprintf(iGeciciDosya, "Nick [%s]^nPassword = %s^nAmmoPacks = %d^n^n", szHesap, szSifre, iCephane);
    }

    fclose(iGeciciDosya);

    if(file_exists(BANK_DOSYASI)) {
        delete_file(BANK_DOSYASI);
    }
    rename_file(szGeciciDosya, BANK_DOSYASI, 1);
}

public YeniRound()
{
    return;
}

public OyuncuDogdu(id)
{
    return;
}

public plugin_end()
{
    new players[32], num;
    get_players(players, num, "ch");

    for(new i = 0; i < num; i++)
    {
        new id = players[i];
        if(g_bGirisYapildi[id] && is_user_connected(id))
        {
            new cephane = zp_get_user_ammo_packs(id);
            if(cephane > 0)
            {
                if((g_iCephanePaketi[id] + cephane) > MAKS_CEPHANE)
                {
                    g_iCephanePaketi[id] = MAKS_CEPHANE;
                }
                else
                {
                    g_iCephanePaketi[id] += cephane;
                }

                zp_set_user_ammo_packs(id, 0);
                MesajGoster(id, "BANK_TRANSFER", cephane);
            }

            OyuncuVerisiniKaydet(id);
        }
    }
}
