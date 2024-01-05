#include <bits/stdc++.h>
using namespace std;

#pragma pack(push)
#pragma pack(1)

struct BootSector {
    uint8_t jump_instruction[3];
    uint8_t oem[8];
    uint16_t bytes_per_sector;
    uint8_t sectors_per_cluster;
    uint16_t reserved_sectors;
    uint8_t fat_count;
    uint16_t dir_entries;
    uint16_t sectors;
    uint8_t media_type;
    uint16_t sectors_per_fat;
    uint16_t sectors_per_track;
    uint16_t heads;
    uint32_t hidden_sectors;
    uint32_t large_sectors;

    uint8_t drive_number;
    uint8_t windows_flag;
    uint8_t signature;
    uint32_t volume_id;
    uint8_t volume_label[11];
    uint8_t system_id[8];

    uint8_t boot_code[448];
    uint8_t end_code[2];
};

struct DirectoryEntry {
    uint8_t name[11];
    uint8_t attribute;
    uint8_t reserved;
    uint8_t created_time_tenth;
    uint16_t created_time;
    uint16_t created_date;
    uint16_t accessed_date;
    uint16_t first_cluster_high;
    uint16_t modified_time;
    uint16_t modified_date;
    uint16_t first_cluster_low;
    uint32_t size;
};

#pragma pack(pop)

class FatDisk : public fstream {
   public:
    BootSector boot_sector;
    uint8_t* fat_chain;
    DirectoryEntry* root_directory;
    uint32_t data_begin;

   public:
    FatDisk(const char* path, ios_base::openmode mode) : fstream(path, mode) {
        if (!is_open()) {
            cerr << "Could not open file: " << path << "\n";
            exit(-1);
        }

        if (!read((char*)&boot_sector, sizeof(boot_sector)).good()) {
            cerr << "Could not read boot sector\n";
            exit(-1);
        }

        if (!read_fat().good()) {
            cerr << "Could not read fat FAT\n";
            exit(-1);
        }

        if (!read_root_directory().good()) {
            cerr << "Could not read fat FAT\n";
            exit(-1);
        }
    }

    istream& read_sectors(uint8_t* buffer, uint32_t lba, uint32_t count) {
        seekg(lba * boot_sector.bytes_per_sector, ios::beg);
        return read((char*)buffer, count * boot_sector.bytes_per_sector);
    }

    istream& read_fat() {
        fat_chain = new uint8_t[boot_sector.sectors_per_fat * boot_sector.bytes_per_sector];
        return read_sectors((uint8_t*)fat_chain, boot_sector.reserved_sectors, boot_sector.sectors_per_fat);
    }

    istream& read_root_directory() {
        uint32_t lba = boot_sector.reserved_sectors + boot_sector.sectors_per_fat * boot_sector.fat_count;
        uint32_t size = sizeof(DirectoryEntry) * boot_sector.dir_entries;
        uint32_t sectors = size / boot_sector.bytes_per_sector;

        // 上高斯
        if (size % boot_sector.bytes_per_sector > 0)
            sectors++;

        data_begin = lba + sectors;
        root_directory = new DirectoryEntry[sectors * boot_sector.bytes_per_sector];
        return read_sectors((uint8_t*)root_directory, lba, sectors);
    }

    DirectoryEntry* find_file(string name) {
        for (uint32_t i = 0; i < boot_sector.dir_entries; i++) {
            if (name == string(reinterpret_cast<char const*>(root_directory[i].name), 11)) {
                return &root_directory[i];
            }
        }
        return nullptr;
    }

    istream& read_file(DirectoryEntry* file_entry, uint8_t* buffer) {
        uint16_t current_cluster = file_entry->first_cluster_low;
        istream& stream = seekg(data_begin, ios::beg);

        do {
            uint32_t lba = data_begin + (current_cluster - 2) * boot_sector.sectors_per_cluster;
            read_sectors(buffer, lba, boot_sector.sectors_per_cluster);
            buffer += boot_sector.sectors_per_cluster * boot_sector.bytes_per_sector;

            uint32_t fat_index = current_cluster * 3 / 2;
            uint16_t next_cluster_pat = *(uint16_t*)(fat_chain + fat_index);
            if (current_cluster % 2 == 0)
                current_cluster = next_cluster_pat & 0x0FFF;
            else
                current_cluster = next_cluster_pat >> 4;

        } while (stream.good() && current_cluster < 0x0FF8);

        return stream;
    }
};

int main(int argc, char** argv) {
    if (argc != 3) {
        cerr << "Syntax: " << argv[0] << " <disk> <target>\n";
        exit(-1);
    }

    FatDisk disk(argv[1], ios::in | ios::binary);

    auto file_entry = disk.find_file(string(argv[2]));
    if (file_entry == nullptr) {
        cerr << "Could not find file: " << argv[2] << "\n";
        exit(-1);
    }

    uint32_t bytes_per_sector = disk.boot_sector.bytes_per_sector;
    uint32_t size = (file_entry->size / bytes_per_sector) * bytes_per_sector;
    if (file_entry->size % bytes_per_sector > 0) size += bytes_per_sector;
    uint8_t* buffer = new uint8_t[size];
    if (!disk.read_file(file_entry, buffer).good()) {
        cerr << "Could not read file: " << argv[2] << "\n";
        exit(-1);
    }

    cout << (char*)buffer << "\n";

    return 0;
}