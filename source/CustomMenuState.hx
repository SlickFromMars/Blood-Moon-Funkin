package;

import flixel.group.FlxSpriteGroup;
import openfl.display.Loader;
#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import Achievements;
import editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;
import FreeplayState.SongMetadata;

class CustomMenuState extends MusicBeatState
{
    var songs:Array<SongMetadata> = [];

    var songList:Array<String> = [
        'tutorial',
        'blackout'
    ];

    public static var unlockList:Array<String> = ['tutorial', 'blackout'];
    public static var firstPlayed:Array<String> = ['tutorial'];

    var debugKeys:Array<FlxKey>;

    private static var curSelected:Int = 0;
	var curDifficulty:Int = 0;
    private static var lastDifficultyName:String = '';

    var scoreBG:FlxSprite;
    var scoreText:FlxText;
    var diffText:FlxText;
    var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
    var intendedRating:Float = 0;

    private var grpSongs:FlxTypedGroup<BetterMenuItem>;

    public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

    override function create() {
        Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
        
        persistentUpdate = true;
		PlayState.isStoryMode = false;
        WeekData.reloadWeekFiles(false);

        if(unlockList != FlxG.save.data.unlockListForCustom) {
            FlxG.save.data.unlockListForCustom = unlockList;
        }

        if(firstPlayed != FlxG.save.data.firstPlayed) {
            FlxG.save.data.firstPlayed = firstPlayed;
        }

        for (i in 0...WeekData.weeksList.length) {
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];
			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.loadTheFirstEnabledMod();

        FlxG.mouse.visible = true;

        #if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

        add(createBG());

        var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + MainMenuState.psychEngineVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 24, 0, "Blood Moon Funkin' v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

        grpSongs = new FlxTypedGroup<BetterMenuItem>();

        for(song in songList) {
            var newGuy:BetterMenuItem = new BetterMenuItem(song, firstPlayed.contains(song), unlockList.contains(song));
            newGuy.screenCenter();

            grpSongs.add(newGuy);
        }

        add(grpSongs);

        scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

        scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

        diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);
        add(scoreText);

        if(curSelected >= songList.length) curSelected = 0;

        super.create();

        changeItem();
		changeDiff();
    }

    var selectedSomethin:Bool = false;

    override function update(elapsed:Float) {
        lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}
		
		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

        if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

        if(!selectedSomethin) {
            if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				selectedSomethin = true;
                FlxG.sound.play(Paths.sound('confirmMenu'));

                persistentUpdate = false;
			    var songLowercase:String = Paths.formatToSongPath(songList[curSelected]);
			    var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			    /*#if MODS_ALLOWED
			        if(!sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) && !sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop))) {
			    #else
			        if(!OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
			    #end
				    poop = songLowercase;
				    curDifficulty = 1;
				    trace('Couldnt find file');
			    }*/
			    trace(poop);

			    PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			    PlayState.isStoryMode = false;
			    PlayState.storyDifficulty = curDifficulty;

			    trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			
			    LoadingState.loadAndSwitchState(new PlayState());

			    FlxG.sound.music.volume = 0;
			}

            #if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
        }

        super.update(elapsed);
    }

    function changeItem(change:Int = 0) {
        curSelected += change;

		if (curSelected < 0)
			curSelected = songList.length - 1;
		if (curSelected >= songList.length)
			curSelected = 0;

        for(spr in grpSongs.members) {
            spr.visible = (spr.myName == songList[curSelected]);
        }
    }

    function changeDiff(change:Int = 0) {
        curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length-1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

        lastDifficultyName = CoolUtil.difficulties[curDifficulty];
    }

    private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

    function createBG():FlxSpriteGroup {
        var bgGrp:FlxSpriteGroup = new FlxSpriteGroup();

        var bg:FlxSprite = new FlxSprite();
        bg.loadGraphic(Paths.image('bg/dark/Red_Bg', 'shared'));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.screenCenter();

        bgGrp.add(bg);

        return bgGrp;
    }
}

class BetterMenuItem extends FlxSprite
{
    public var myName:String;

    public function new(name:String, useNewSprite:Bool, useLockSprite:Bool) {
        super();

        this.myName = name;

        var path = 'customMenu/$name';
        if(useNewSprite) path = 'customMenu/new';
        if(useLockSprite) path = 'customMenu/lock';

        if(Paths.fileExists(path, IMAGE)) {
            this.loadGraphic(Paths.image(path));
        } else {
            this.loadGraphic(Paths.image('customMenu/new'));
        }
    }
}