const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const Float = firefly.utils.Float;

//////////////////////////////////////////////////////////////
//// audio init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.Subtype.register(api.Asset, Sound, "Sound");
    api.Component.Subtype.register(api.Asset, Music, "Music");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// audio API
//////////////////////////////////////////////////////////////

pub const AudioPlayer = struct {
    pub fn playSoundById(id: Index, override: bool) void {
        playSoundByIdPro(id, null, null, null, override);
    }

    pub fn playSoundByIdPro(
        id: Index,
        volume: ?Float,
        pitch: ?Float,
        pan: ?Float,
        channel: ?usize,
        override: bool,
    ) void {
        if (Sound.getResourceById(id)) |sound| playSound(
            sound,
            volume,
            pitch,
            pan,
            channel,
            override,
        );
    }

    pub fn playSoundByName(name: String, override: bool) void {
        playSoundByNamePro(name, null, null, null, override);
    }

    pub fn playSoundByNamePro(
        name: String,
        volume: ?Float,
        pitch: ?Float,
        pan: ?Float,
        channel: ?usize,
        override: bool,
    ) void {
        if (Sound.getResourceByName(name)) |sound| playSound(
            sound,
            volume,
            pitch,
            pan,
            channel,
            override,
        );
    }

    inline fn playSound(sound: *Sound, volume: ?Float, pitch: ?Float, pan: ?Float, channel: ?usize, override: bool) void {
        if (sound._binding) |bind| {
            var bindingId = bind.id;
            if (channel) |c| {
                switch (c) {
                    1 => bindingId = bind.channel_1 orelse bind.id,
                    2 => bindingId = bind.channel_2 orelse bind.id,
                    3 => bindingId = bind.channel_3 orelse bind.id,
                    4 => bindingId = bind.channel_4 orelse bind.id,
                    5 => bindingId = bind.channel_5 orelse bind.id,
                    6 => bindingId = bind.channel_6 orelse bind.id,
                }
            }

            if (!override and firefly.api.audio.isSoundPlaying(bindingId))
                return;

            firefly.api.audio.playSound(
                bindingId,
                volume orelse sound.volume,
                pitch orelse sound.pitch,
                pan orelse sound.pan,
            );
        }
    }

    pub fn playMusicById(id: Index, override: bool) void {
        playMusicByIdPro(id, null, null, null, override);
    }

    pub fn playMusicByIdPro(id: Index, volume: ?Float, pitch: ?Float, pan: ?Float, override: bool) void {
        if (Music.getResourceById(id)) |music| playMusic(music, volume, pitch, pan, override);
    }

    pub fn playMusicByName(name: String, override: bool) void {
        playMusicByNamePro(name, null, null, null, override);
    }

    pub fn playMusicByNamePro(name: String, volume: ?Float, pitch: ?Float, pan: ?Float, override: bool) void {
        if (Music.getResourceByName(name)) |music| playMusic(music, volume, pitch, pan, override);
    }

    inline fn playMusic(music: *Music, volume: ?Float, pitch: ?Float, pan: ?Float, override: bool) void {
        if (music._binding) |bind| {
            if (!override and firefly.api.audio.isMusicPlaying(bind))
                return;

            firefly.api.audio.playMusic(
                bind,
                volume orelse music.volume,
                pitch orelse music.pitch,
                pan orelse music.pan,
            );
        }
    }
};

//////////////////////////////////////////////////////////////
//// Sound Asset
//////////////////////////////////////////////////////////////

pub const Sound = struct {
    pub const Component = api.Component.SubTypeMixin(api.Asset, Sound);

    id: Index = UNDEF_INDEX,
    name: String,
    resource: String,
    volume: Float = 1,
    pitch: Float = 0,
    pan: Float = 0,
    channels: usize = 0,

    _binding: ?api.SoundBinding = null,

    pub fn activation(self: *Sound, active: bool) void {
        if (active) {
            if (self._binding != null)
                return; // already loaded

            self._binding = firefly.api.audio.loadSound(self.resource, self.channels) catch |err| {
                api.Logger.errWith("Failed to load sound from: {any}", .{self}, err);
                api.Asset.assetLoadError(self.id, api.IOErrors.LOAD_SOUND_ERROR);
                return;
            };
            api.Asset.assetLoaded(self.id, true);
        } else {
            if (self._binding) |b| {
                firefly.api.audio.disposeSound(b);
                self._binding = null;
            }
            api.Asset.assetLoaded(self.id, false);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Music Asset
//////////////////////////////////////////////////////////////

pub const Music = struct {
    pub const Component = api.Component.SubTypeMixin(api.Asset, Music);

    id: Index = UNDEF_INDEX,
    name: String,
    resource: String,
    volume: Float = 1,
    pitch: Float = 0,
    pan: Float = 0,

    _binding: ?api.BindingId = null,

    pub fn activation(self: *Music, active: bool) void {
        if (active) {
            if (self._binding != null)
                return; // already loaded

            self._binding = firefly.api.audio.loadMusic(self.resource) catch |err| {
                api.Logger.errWith("Failed to load music from: {any}", .{self}, err);
                api.Asset.assetLoadError(self.id, api.IOErrors.LOAD_SOUND_ERROR);
                return;
            };
            api.Asset.assetLoaded(self.id, true);
        } else {
            if (self._binding) |b| {
                firefly.api.audio.disposeMusic(b);
                self._binding = null;
            }
            api.Asset.assetLoaded(self.id, false);
        }
    }
};
