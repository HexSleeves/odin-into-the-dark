package gameinput

death_sound_played: bool

// quit_armed: first Escape press during Playing arms this flag.
// A second Escape press within the same state will actually quit.
// Any other key (or leaving Playing state) clears it.
quit_armed: bool
