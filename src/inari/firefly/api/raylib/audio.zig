const std = @import("std");
const firefly = @import("../../firefly.zig");
const rl = @cImport(@cInclude("raylib.h"));
const utils = firefly.utils;
const api = firefly.api;

const IAudioAPI = api.IAudioAPI;
const SoundBinding = api.SoundBinding;
const DynArray = utils.DynArray;
const Sound = rl.Sound;
const Music = rl.Music;
const Float = utils.Float;
const String = utils.String;
const BindingId = api.BindingId;

var singleton: ?IAudioAPI() = null;
pub fn createInputAPI() !IAudioAPI() {
    if (singleton == null)
        singleton = IAudioAPI().init(RaylibAudioAPI.initImpl);

    return singleton.?;
}

const RaylibAudioAPI = struct {
    var initialized = false;

    var sounds: DynArray(Sound) = undefined;
    var music: DynArray(Music) = undefined;

    fn initImpl(interface: *IAudioAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        sounds = DynArray(Sound).new(api.ALLOC) catch unreachable;
        music = DynArray(Music).new(api.ALLOC) catch unreachable;

        interface.initAudioDevice = initAudioDevice;
        interface.closeAudioDevice = closeAudioDevice;
        interface.setMasterVolume = setMasterVolume;
        interface.getMasterVolume = getMasterVolume;

        interface.loadSound = loadSound;
        interface.disposeSound = disposeSound;
        interface.playSound = playSound;
        interface.stopSound = stopSound;
        interface.pauseSound = pauseSound;
        interface.resumeSound = resumeSound;
        interface.isSoundPlaying = isSoundPlaying;
        interface.setSoundVolume = setSoundVolume;
        interface.setSoundPitch = setSoundPitch;
        interface.setSoundPan = setSoundPan;

        interface.loadMusic = loadMusic;
        interface.disposeMusic = disposeMusic;
        interface.playMusic = playMusic;
        interface.stopMusic = stopMusic;
        interface.pauseMusic = pauseMusic;
        interface.resumeMusic = resumeMusic;
        interface.isMusicPlaying = isMusicPlaying;
        interface.setMusicVolume = setMusicVolume;
        interface.setMusicPitch = setMusicPitch;
        interface.setMusicPan = setMusicPan;
        interface.getMusicTimeLength = getMusicTimeLength;
        interface.getMusicTimePlayed = getMusicTimePlayed;

        interface.deinit = deinit;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        var next = sounds.slots.nextSetBit(0);
        while (next) |i| {
            rl.UnloadSoundAlias(sounds.get(i).?.*);
            next = sounds.slots.nextSetBit(i + 1);
        }
        sounds.clear();
        sounds.deinit();

        next = music.slots.nextSetBit(0);
        while (next) |i| {
            disposeMusic(i);
            next = music.slots.nextSetBit(i + 1);
        }
        music.clear();
        music.deinit();
    }

    fn initAudioDevice() void {
        rl.InitAudioDevice();
    }

    fn closeAudioDevice() void {
        rl.CloseAudioDevice();
    }

    fn setMasterVolume(volume: Float) void {
        rl.SetMasterVolume(volume);
    }

    fn getMasterVolume() Float {
        return rl.GetMasterVolume();
    }

    fn loadSound(file: String, channels: usize) SoundBinding {
        const sound = rl.LoadSound(@ptrCast(file));
        var sound_binding = SoundBinding{ .id = sounds.add(sound) };
        if (channels > 0) sound_binding.channel_1 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels > 1) sound_binding.channel_2 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels > 2) sound_binding.channel_3 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels > 3) sound_binding.channel_4 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels > 4) sound_binding.channel_5 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels > 5) sound_binding.channel_6 = sounds.add(rl.LoadSoundAlias(sound));

        return sound_binding;
    }

    fn disposeSound(binding: SoundBinding) void {
        if (binding.channel_1) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };
        if (binding.channel_2) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };
        if (binding.channel_3) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };
        if (binding.channel_4) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };
        if (binding.channel_5) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };
        if (binding.channel_6) |cb| if (sounds.get(cb)) |s| {
            rl.UnloadSoundAlias(s.*);
            sounds.remove(s);
        };

        if (sounds.get(binding.id)) |s| {
            rl.UnloadSound(s.*);
            sounds.remove(s);
        }
    }

    fn playSound(id: BindingId, volume: ?Float, pitch: ?Float, pan: ?Float) void {
        if (sounds.get(id)) |sound| {
            if (volume) |v| rl.SetSoundVolume(sound.*, v);
            if (pitch) |p| rl.SetSoundPitch(sound.*, p);
            if (pan) |p| rl.SetSoundPan(sound.*, p);

            rl.PlaySound(sound.*);
        }
    }

    fn stopSound(id: BindingId) void {
        if (sounds.get(id)) |sound| {
            rl.StopSound(sound.*);
        }
    }

    fn pauseSound(id: BindingId) void {
        if (sounds.get(id)) |sound| {
            rl.PauseSound(sound.*);
        }
    }

    fn resumeSound(id: BindingId) void {
        if (sounds.get(id)) |sound| {
            rl.ResumeSound(sound.*);
        }
    }

    fn isSoundPlaying(id: BindingId) bool {
        if (sounds.get(id)) |sound| {
            return rl.IsSoundPlaying(sound.*);
        }
        return false;
    }

    fn setSoundVolume(id: BindingId, volume: Float) void {
        if (sounds.get(id)) |sound| {
            rl.SetSoundVolume(sound.*, volume);
        }
    }

    fn setSoundPitch(id: BindingId, pitch: Float) void {
        if (sounds.get(id)) |sound| {
            rl.SetSoundPitch(sound.*, pitch);
        }
    }

    fn setSoundPan(id: BindingId, pan: Float) void {
        if (sounds.get(id)) |sound| {
            rl.SetSoundPan(sound.*, pan);
        }
    }

    fn loadMusic(file: String) BindingId {
        const m = rl.LoadMusicStream(@ptrCast(file));
        return music.add(m);
    }

    fn disposeMusic(id: BindingId) void {
        if (music.get(id)) |m| {
            music.remove(m);
            rl.UnloadMusicStream(m.*);
        }
    }

    fn playMusic(id: BindingId) void {
        if (music.get(id)) |m| {
            rl.PlayMusicStream(m.*);
        }
    }

    fn stopMusic(id: BindingId) void {
        if (music.get(id)) |m| {
            rl.StopMusicStream(m.*);
        }
    }

    fn pauseMusic(id: BindingId) void {
        if (music.get(id)) |m| {
            rl.PauseMusicStream(m.*);
        }
    }

    fn resumeMusic(id: BindingId) void {
        if (music.get(id)) |m| {
            rl.ResumeMusicStream(m.*);
        }
    }

    fn isMusicPlaying(id: BindingId) bool {
        if (music.get(id)) |m| {
            return rl.IsMusicStreamPlaying(m.*);
        }
        return false;
    }

    fn setMusicVolume(id: BindingId, volume: Float) void {
        if (music.get(id)) |m| {
            rl.SetMusicVolume(m.*, volume);
        }
    }

    fn setMusicPitch(id: BindingId, pitch: Float) void {
        if (music.get(id)) |m| {
            rl.SetMusicPitch(m.*, pitch);
        }
    }

    fn setMusicPan(id: BindingId, pan: Float) void {
        if (music.get(id)) |m| {
            rl.SetMusicPan(m.*, pan);
        }
    }

    fn getMusicTimeLength(id: BindingId) Float {
        if (music.get(id)) |m| {
            return rl.GetMusicTimeLength(m.*);
        }
        return -1;
    }

    fn getMusicTimePlayed(id: BindingId) Float {
        if (music.get(id)) |m| {
            return rl.GetMusicTimePlayed(m.*);
        }
        return -1;
    }
};
