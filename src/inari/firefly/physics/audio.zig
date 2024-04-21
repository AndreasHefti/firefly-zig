const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const Component = api.Component;
const Index = utils.Index;
const Float = utils.Float;
const Asset = api.Asset;
const String = utils.String;
const BindingId = api.BindingId;
const SoundBinding = api.SoundBinding;

//////////////////////////////////////////////////////////////
//// audio init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(Asset(Sound));
    Component.registerComponent(Asset(Music));
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

    pub fn playSoundByIdPro(id: Index, volume: ?Float, pitch: ?Float, pan: ?Float, channel: ?usize, override: bool) void {
        if (Sound.getResourceById(id)) |sound| playSound(sound, volume, pitch, pan, channel, override);
    }

    pub fn playSoundByName(name: String, override: bool) void {
        playSoundByNamePro(name, null, null, null, override);
    }

    pub fn playSoundByNamePro(name: String, volume: ?Float, pitch: ?Float, pan: ?Float, channel: ?usize, override: bool) void {
        if (Sound.getResourceByName(name)) |sound| playSound(sound, volume, pitch, pan, channel, override);
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

            if (!override and api.audio.isSoundPlaying(bindingId))
                return;

            api.audio.playSound(
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
            if (!override and api.audio.isMusicPlaying(bind))
                return;

            api.audio.playMusic(
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
    pub usingnamespace firefly.api.AssetTrait(Sound, "Sound");

    name: String,
    resource: String,
    volume: Float = 1,
    pitch: Float = 0,
    pan: Float = 0,
    channels: usize = 0,

    _binding: ?SoundBinding = null,

    pub fn doLoad(_: *Asset(Sound), resource: *Sound) void {
        if (resource._binding != null)
            return; // already loaded

        resource._binding = api.audio.loadSound(resource.resource, resource.channels);
    }

    pub fn doUnload(_: *Asset(Sound), resource: *Sound) void {
        if (resource._binding) |b| {
            api.audio.disposeSound(b);
            resource._binding = null;
        }
    }
};

//////////////////////////////////////////////////////////////
//// Music Asset
//////////////////////////////////////////////////////////////

pub const Music = struct {
    pub usingnamespace firefly.api.AssetTrait(Music, "Music");

    name: String,
    resource: String,
    volume: Float = 1,
    pitch: Float = 0,
    pan: Float = 0,

    _binding: ?BindingId = null,

    pub fn doLoad(_: *Asset(Music), resource: *Music) void {
        if (resource._binding != null)
            return; // already loaded

        resource._binding = api.audio.loadMusic(resource.resource);
    }

    pub fn doUnload(_: *Asset(Music), resource: *Music) void {
        if (resource._binding) |b| {
            api.audio.disposeMusic(b);
            resource._binding = null;
        }
    }
};
