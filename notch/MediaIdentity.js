.pragma library

function snapshot(player) {
    const metadata = player.metadata || {};
    let url = String(metadata["xesam:url"] || "");
    // A YouTube timestamp, playlist or tracking parameter isn't a new video.
    const youtube = url.match(/^https?:\/\/(?:www\.|m\.|music\.)?youtube\.com\/watch\?([^#]*)/i);
    const video = youtube && youtube[1].match(/(?:^|&)v=([^&]+)/);
    const short = url.match(/^https?:\/\/youtu\.be\/([^?/#]+)/i);
    const shorts = /^https?:\/\/(?:www\.|m\.)?youtube\.com\/shorts(?:\/|[?#]|$)/i.test(url);
    if (video || short) url = "youtube:" + (video ? video[1] : short[1]);
    return {
        player: player.dbusName,
        url: url,
        shorts: shorts,
        title: player.trackTitle || "",
        artist: player.trackArtist || "",
        album: player.trackAlbum || ""
    };
}

function sameTrack(previous, current) {
    if (!previous || !current || previous.player !== current.player) return false;
    // Shorts page navigation and MediaSession metadata can arrive separately.
    // Follow the media title; a later page URL update must not announce it again.
    if (previous.shorts && current.shorts) return previous.title === current.title;
    if (previous.url && current.url) {
        if (previous.url !== current.url) return false;
        return true;
    }
    // Metadata may arrive in pieces, or a player may not provide a URL at all.
    return previous.title === current.title
        && previous.artist === current.artist && previous.album === current.album;
}
