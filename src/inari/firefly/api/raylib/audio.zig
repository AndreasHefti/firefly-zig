const std = @import("std");
const firefly = @import("../../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;
const rl = @cImport(@cInclude("raylib.h"));

const Float = firefly.utils.Float;
const String = firefly.utils.String;
const BindingId = firefly.api.BindingId;

var singleton: ?api.IAudioAPI() = null;
pub fn createAudioAPI() !api.IAudioAPI() {
    if (singleton == null)
        singleton = api.IAudioAPI().init(RaylibAudioAPI.initImpl);

    return singleton.?;
}

const RaylibAudioAPI = struct {
    var initialized = false;

    var sounds: utils.DynArray(rl.Sound) = undefined;
    var music: utils.DynArray(rl.Music) = undefined;
    var looping_sounds: utils.BitSet = undefined;

    fn initImpl(interface: *api.IAudioAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        sounds = utils.DynArray(rl.Sound).new(firefly.api.ALLOC);
        music = utils.DynArray(rl.Music).new(firefly.api.ALLOC);
        looping_sounds = utils.BitSet.new(firefly.api.ALLOC);

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
        interface.updateMusicStream = updateMusicStream;
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

        rl.InitAudioDevice();
        api.subscribeUpdate(updateLoopingSounds);
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        api.unsubscribeUpdate(updateLoopingSounds);
        var next = sounds.slots.nextSetBit(0);
        while (next) |i| {
            rl.UnloadSoundAlias(sounds.get(i).?.*);
            next = sounds.slots.nextSetBit(i + 1);
        }
        sounds.clear();
        sounds.deinit();
        looping_sounds.deinit();

        next = music.slots.nextSetBit(0);
        while (next) |i| {
            disposeMusic(i);
            next = music.slots.nextSetBit(i + 1);
        }
        music.clear();
        music.deinit();

        rl.CloseAudioDevice();
    }

    pub fn updateLoopingSounds(_: api.UpdateEvent) void {
        var next = looping_sounds.nextSetBit(0);
        while (next) |i| {
            next = looping_sounds.nextSetBit(i + 1);
            if (sounds.get(i)) |s| {
                if (!rl.IsSoundPlaying(s.*)) {
                    rl.PlaySound(s.*);
                }
            }
        }
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

    fn loadSound(file: String, channels: utils.IntBitMask) api.IOErrors!api.SoundBinding {
        const name = api.ALLOC.dupeZ(u8, file) catch |err| api.handleUnknownError(err);
        defer api.ALLOC.free(name);

        const sound = rl.LoadSound(name);
        if (!rl.IsSoundValid(sound))
            return api.IOErrors.LOAD_SOUND_ERROR;

        var sound_binding = api.SoundBinding{ .id = sounds.add(sound) };

        if (channels & utils.maskBit(0) != 0) sound_binding.channel_1 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels & utils.maskBit(1) != 0) sound_binding.channel_2 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels & utils.maskBit(2) != 0) sound_binding.channel_3 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels & utils.maskBit(3) != 0) sound_binding.channel_4 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels & utils.maskBit(4) != 0) sound_binding.channel_5 = sounds.add(rl.LoadSoundAlias(sound));
        if (channels & utils.maskBit(5) != 0) sound_binding.channel_6 = sounds.add(rl.LoadSoundAlias(sound));

        return sound_binding;
    }

    fn disposeSound(binding: api.SoundBinding) void {
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

    fn playSound(id: BindingId, volume: ?Float, pitch: ?Float, pan: ?Float, looping: bool) void {
        if (sounds.get(id)) |sound| {
            if (volume) |v| rl.SetSoundVolume(sound.*, v);
            if (pitch) |p| rl.SetSoundPitch(sound.*, p);
            if (pan) |p| rl.SetSoundPan(sound.*, p);
            if (looping) looping_sounds.set(id);

            rl.PlaySound(sound.*);
        }
    }

    fn stopSound(id: BindingId) void {
        if (sounds.get(id)) |sound| {
            rl.StopSound(sound.*);
            looping_sounds.setValue(id, false);
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

    fn loadMusic(file: String) api.IOErrors!BindingId {
        const name = api.ALLOC.dupeZ(u8, file) catch |err| api.handleUnknownError(err);
        defer api.ALLOC.free(name);

        const m = rl.LoadMusicStream(name);
        if (!rl.IsMusicValid(m))
            return api.IOErrors.LOAD_MUSIC_ERROR;

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

    fn updateMusicStream(id: BindingId) void {
        if (music.get(id)) |m| {
            rl.UpdateMusicStream(m.*);
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
