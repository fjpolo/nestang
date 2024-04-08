#ifndef FIRMWARE_H
#define FIRMWARE_H

// Cheats
#define CHEATS_BYTES_PER_CHEAT 8
#define CHEATS_CHARS_PER_CHEAT (CHEATS_BYTES_PER_CHEAT * 3) // 2 char per hex value + \n or EOF
#define CHEATS_MAX_CHEATS 32
#define CHEATS_TOTAL_BYTES (CHEATS_MAX_CHEATS * CHEATS_BYTES_PER_CHEAT)
#define CHEATS_TOTAL_CHARS (CHEATS_MAX_CHEATS * CHEATS_CHARS_PER_CHEAT)

typedef enum{
    GAME_LOAD_STATE_OK = 0x00,
    GAME_LOAD_STATE_FILE_NOT_EXIST = 0x01,
    GAME_LOAD_STATE_FILE_CORRUPT = 0x02,
}GAME_LOAD_STATE;

typedef enum{
    MENU_CHOICES_LOAD_ROM_FROM_SDCARD = 0x00,
    MENU_CHOICES_CHEATS_ENABLE = 0x01,
    MENU_CHOICES_OPTIONS = 0x02,
    /* Keep this one */
    MENU_CHOICES_END
}MENU_CHOICES;


// Load backup file content into SNES BSRAM. If no such file exists, this creates an empty one.
// name: save file name (.srm)
// size: in number of KB
void backup_load(char *name, int size);

// Save current BSRAM content on to SD card.
// name: save file name (.srm)
// size: in number of KB
int backup_save(char *name, int size);

// Saves every 10 seconds
void backup_process();

int loadnes(int rom);
int loadsnes(int rom);

void message(char *msg, int center);

void status(char *msg);

#define CRC16 0x8005

uint16_t gen_crc16(const uint8_t *data, uint16_t size);

#endif