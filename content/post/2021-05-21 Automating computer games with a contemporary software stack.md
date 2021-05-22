---
title: Automating computer games with a contemporary software stack
date: '2021-05-21'
categories:
  - Programming
  - Games
description: How to design a bot / macro / script to automate the game RuneScape using Python and rudimentary computer vision techniques.
slug: automating-computer-games
toc: true
---

## A historical perspective on automation

As I've [mentioned before](/post/2021/04/25/windmouse-human-mouse-movement/#context), the desire to automate (cheat, bot, macro, ...) games like [RuneScape](https://runescape.com) was the primary reason I learned to program at such a young age.
Back in 2002, there was no [Stack Overflow](https://en.wikipedia.org/wiki/Stack_Overflow) to rely on for code snippets, no [Reddit](https://reddit.com) to connect me with like-minded individuals in the niche of game automation, and (thankfully) no [YouTube](https://youtube.com) to host poorly-edited video tutorials.
The one saving grace was that [Google](https://google.com), at least, had been around for four years, so twelve-year-old-me could google for "runescape cheats" and find utilities people had designed to make the game less monotonous.

### The early days

The earliest automation utilities could record and replay mouse actions, which worked well enough.
Eventually the developers of Runescape added some random rotation mechanics to the game to defeat these static clickers.
The rotation caused these repeated actions to diverge from what was intended on the scale of minutes, since each slight error compounded over time.
{{< figure src="/images/sherlock_autominer.gif" class="rightsmall" caption="Nick Sherlock's Autominer interface from the Black Book of RS Cheating" >}}
To defeat the rotation mechanic, someone who went by Nick Sherlock designed a program called Autominer, which was a pre-baked (i.e. minimally configurable) task automation program that searched for colors on the game screen to determine what to click next.
Autominer, as the name suggests, primarily automated the task of mining, and could be set to work at several different locations in the game.
Because it was pre-baked and no source code was available, it was virtually impossible to extend Autominer's functionality to other areas of the game.
Both Autominer and Nick Sherlock are lost to the early days of the internet; even the [Wayback Machine](https://archive.org/web/) is no help here.

{{< figure src="/images/kaitnieks_scar.gif" class="rightsmall" caption="Kaitnieks' SCAR from the Black Book of RS Cheating" >}}
Later, someone who went by [Kaitnieks](https://web.archive.org/web/20040315042256/http://kaitnieks.com/) (who the Wayback Machine has only archived post-retirement) developed a program called [SCAR](https://web.archive.org/web/20040610205947/http://kaitnieks.com/scar/).
SCAR had a scriptable interface, using [Pascal](https://en.wikipedia.org/wiki/Pascal_(programming_language)) (of all languages) to allow the user to develop arbitrary logic.
Importantly, it included an API exposing a suite of rudimentary [computer vision](https://en.wikipedia.org/wiki/Computer_vision) techniques for analyzing the game screen and deciding what to click.
Because it was scriptable, anyone could contribute and share ideas about how to automate aspects of the game, and anyone could update script logic as the game changed.
This led to a very active community of fledgling programmers congregating at Kaitnieks' forums, and contributed to SCAR being one of the longest-lived Runescape automation utilities.

When Kaitnieks closed his fourms, a large component of the programming community there moved to the [SRL Forums](https://villavu.com/) (still exist but _totally dead_) to continue development of the SRL Resource Library (or SCAR Resource Library, at that time).
SRL was/is a standard library or large body of Pascal routines that acts as a common base from which Runescape scripts can be developed, and I contributed a decent amount to it over the years, including the base [mouse motion algorithm](/post/2021/04/25/windmouse-human-mouse-movement/).
Someone who went by [Freddy1990](https://freddy1990.net/) took over development of SCAR, but it remained closed source, and _nobody liked his attitude_, so the SRL community (primarily [Wizzup](https://wizzup.org/)) developed a [free and open source](https://en.wikipedia.org/wiki/Free_and_open-source_software) clone, [Simba](https://github.com/MerlijnWajer/Simba/), which still sees wide and varied use today.

### But what about now?

Pascal is a dinosaur of a language, and even though effort has been made to add nonstandard features to the [implementation used in Simba](https://github.com/nielsAD/lape/), it remains clunky compared to modern languages like Python.
Similarly, Simba is quite solid, but ultimately it's a Pascal sandbox that was designed as a clone of a program whose feature set is nominally pegged at what it could do in 2002.
Nearly twenty years have elapsed since then, the Python ecosystem has grown exponentially, and modern high-level languages are more accessible than ever before with software suites like [Anaconda](https://www.anaconda.com/) dumping a whole data science toolkit onto your laptop with a few clicks.
Plus, Stack Overflow exists now, so you really don't even need to know any python as long as you can frame your goals as a question and type them into google. 
Chances are someone has done (at least parts of) it and posted the code already. 

All this is to say that if one wanted to automate Runescape in 2021, one would do it in Python, and have access to an enormous suite of tools to choose from.
(In principle, anyway, since I get a kick of out implementing algorithms myself.)
Even better, learning Python is a useful and marketable skill, arguably much more so than Pascal.
So a while ago, I decided to do just that, and developed a minimal clone of SRL in Python along with a few scripts, which can be found in the [srbot repository](https://github.com/BenLand100/srbot).
Because I don't play Runescape anymore, and haven't for a decade, I decided to do this on a Runescape private server [2006Scape](https://2006scape.org/) that implements a version of the game circa 2006 and is friendly to automation.
These scripts and techniques would translate well to the official OldSchool Runescape, which is almost the same level of nostalgic, or so I hear.

## Automation methodology 

Imaging the game window and deciding what to do (click) next is the basic idea here.
There are, of course, other methods of interrogating the game state and causing actions to happen, but the imaging and clicking method is most like how a real human would play the game.
To image the game, I opted to use `pyautogui.screenshot`, and for interacting with the game client, I'll also use the key and mouse interfaces of the [PyAutoGUI](https://pyautogui.readthedocs.io/en/latest/) package.

### Image analysis

Analyzing these images requires a basic understanding of how computers represent images: as a two dimensional array of pixels, where each pixels is a tuple of three values representing red, green, and blue intensity. 
Historically, each color (channel) has been represented by a single byte, meaning the intensity is an integer from $[0,255]$.
Taken together, this means each 2D image can be represented by a 3D array of bytes, where the first dimension is the color channel (red, green, blue), and the last two dimensions are the horizontal and vertical location of a pixel. 
Sometimes the order of the spatial and color dimensions are swapped, but `srbot` always works with the above scheme.
The `srbot.io` module has several methods that use PyAutoGUI to acquire images of parts of the game client and represent them as 3D NumPy arrays.
```python
def get_client():
    return np.asarray(pyautogui.screenshot(region=(client_pos[0],client_pos[1],w,h)))
```

{{< figure src="/images/rs_example.png" class="center" caption="A snapshot of the OSRS / 2006Scape game client." >}}
Once these images are acquired, the task is to extract useful information from them.
The game has three different graphical regions to consider:

* The inventory and chat areas which are flat 2D renderings of static images or bitmap fonts.
* The minimap, which is a 2D top-down rendering of the world, centered on your character, and loosely tracks the rotation of the mainscreen camera. A subtle color transformation happens in the minimap in an attempt to throw off would-be automators. 
* The mainscreen region, which is a 3D perspective rendering of low-triangle models. The camera can be moved around the surface of a hemisphere centered on your character using arrow keys. In certain circumstances, 2D interfaces will appear here.

Different techniques are able to efficiently extract information from these different regions, and are discussed in the following sections.

#### Inventory analysis

This is the simplest of the three regions, since it consists only of 2D images with no rotation, scaling, or color transformations applied.
Therefore, most things one might want to find in this region can be identified by a rectangular region of particular colors, or in plainer terms, a sub-image. 
[Bitmap](https://en.wikipedia.org/wiki/Bitmap) matching or template matching are the colloquial terms for the technique of comparing two images.
In principle, to find a sub-image in a larger image, one compares the desired sub-image to every possible sub-image of the same size present in the larger image.
[OpenCV's template matching](https://docs.opencv.org/master/d4/dc6/tutorial_py_template_matching.html) algorithms provide many generic ways to do this, and would be easy to import in Python.
If you know me, though, you know that I love to play with multidimensional array indexing and implementing my own algorithms, so `srbot.bitmap` contains (nearly) pure Python implementations of similar techniques in the `find_bitmap_prob` function.

In this particular case, OpenCV's template matching is overkill, since they are optimized to look for partial matches instead of exact matches, and provide a "match score" at every location in the larger image.
Instead, I propose an optimization strategy as follows:

1. Locate any pixels in the larger image that match the pixel at $(0,0)$ (upper right) of the sub-image
2. Retain any potential matches that also contain the $(1,0)$ pixel in the sub-image immediately to the right of the first match.
3. Continue through the other pixels in the sub-image, excluding any potential matches that lack the sub-image's 

This can either look for exact matches, or allow for some tolerance at each pixel to get partial matches.
This has an efficient implementation in `srbot.bitmap` as well:
```python
def find_bitmap(bmp,region,tol=0.01,mask=None,mode='dist'):
    '''similar to find_bitmap_prob but uses the heuristic that each pixel must match better than some tolerance.
       Only returns the coordinates of potential matches.'''
    xs,ys=0,0
    hr,wr=region.shape[:2]
    hs,ws=bmp.shape[:2]
    cmp = get_cmp(mode)
    if mask is None:
        candidates = np.asarray(np.nonzero(cmp(bmp[0,0],region[:-hs,:-ws],tol)))
    else:
        candidates = np.asarray(np.nonzero(np.ones((hr-hs+1,wr-ws+1))))
    for i in np.arange(0,hs):
        for j in np.arange(0,ws):
            if (mask is None and i==0 and j==0) or (mask is not None and not mask[i,j]):
                continue
            view = region[candidates[0]+i,candidates[1]+j,:]
            passed = cmp(bmp[i,j],view,tol)
            candidates = candidates.T[passed].T        
    return candidates[[1,0],:].T
```

#### Minimap analysis

Because the minimap rotates, and more importantly rotates subtly on its own to defeat automation, finding exact rectangular images isn't as practical.
A slight exception here are certain "icons" (see the dollar symbol symbolizing the bank in the earlier image) which maintain their orientation as the minimap rotates, however the dots that signify items, players, or NPCs can occlude these, so at best probabilistic matching is needed, or at worst they are unreliable.
It is possible to generalize bitmap matching to include a rotation of the sub-image, however this additional free parameter makes for a much more complicated comparison.

A better approach here would have some kind of rotational invariance, meaning regions of the minimap could be identified regardless of what the minimap rotation happens to be.
After taking enough math and physics courses, one would know of several rotationally invariant quantities: area, angle (between two vectors), and length.
This means that, regardless of the rotation, the number of pixels with the same/similar color (area), the distance between features (length), and their relative orientations (angle) will remain roughly constant. 
Roughly, here, because the discrete nature of computer images means rotations are not smooth, though this can be hidden to an extent with algorithms that computes weighted averages of several pixels that, when rotated, overlap a single pixel.

So in a schematic sense, identifying features on the minimap can be generalized to identifying regions of similar colors and comparing the orientation and distances between those regions. 
I'll get to comparing colors later, but taking it for granted that a set of points corresponding to colors that are the same within some tolerance can be found, an algorithm to cluster this set of points into separate regions is often required.
The `srbot.algorithm` module contains a `cluster` method that does just that with the following logic:

1. Pick a random point in the set that has not been assigned to a cluster.
2. Calculate the distance between that point and all points.
3. Any point within a certain distance of the candidate point is assigned to a cluster.
4. If any of those points already belonged to a cluster, those clusters are merged.
5. Repeat steps until there are no points that have not been assigned to a cluster.

```python
def cluster(points,radius=5):
    '''groups points separated by no more than radius from another point in the group
       returns a list of the groups, and the length of each group'''
    clusters = np.zeros(len(points),dtype='uint32')
    while True: #loop until all points are clustered
        unclustered = clusters==0
        remaining = np.count_nonzero(unclustered)
        if remaining == 0:
            break 
        # any points near this group (and their points) become a new group
        candidate = points[unclustered][np.random.randint(remaining)] #do this randomly to save time
        dist = np.sum(np.square(points-candidate),axis=1)
        nearby_mask = dist<=radius*radius #importantly includes candidate point
        overlaps = set(list(clusters[nearby_mask])) #groups that were close
        overlaps.remove(0)
        if len(overlaps) == 0:
            G = np.max(clusters)+1 #new cluster
        else:
            G = np.min(list(overlaps)) #prefer smaller numbers
        #set all nearby clusters to index G
        clusters[nearby_mask] = G
        for g in overlaps:
            if g == G or g == 0:
                continue
            clusters[clusters==g] = G
    unique, counts = np.unique(clusters, return_counts=True)
    cluster_points = np.asarray([points[clusters==c] for c in unique],dtype='object')
    return cluster_points,counts
```
{{< figure src="/images/rs_bank_diagnostic.png" class="rightsmall" caption="A diagnostic view of the algorithm to find the banker NPC cluster. Note: things moved a bit relative to the image shown before." >}}
{{< figure src="/images/rs_bank.png" class="rightsmall" caption="A screenshot of the client while standing in the Falador East bank." >}}

As a concrete example, consider trying to find the bank on the minimap.
One could attempt to click the bank icon, but it may be occluded, or may have moved (again, to defeat automation).
A relative constant, though, is the cluster of yellow dots, representing the banker NPCs
However, there could be other NCPs on the minimap, so disentangling the banker NPCs from other NPCs is necessary.
One approach would be to identify a yellow cluster with a high enough distance tolerance that would include all the bankers, and click the biggest cluster.
In practice, this works fine.
The following code shows a diagnostic view of what the algorithm sees, with any colors matching the NPC color shown in blue, the largest cluster in green, and the match to the bank symbol (unused) with a red dot for good measure.

```python
minimap = get_minimap()

bank_icon = load_image('bank_icon.png')    
bank = find_best_bitmap(bank_icon,minimap,tol=0.1,mode='xcorr')

npc = find_colors([238,238,0],minimap,mode='hsl',tol=0.15)
clusters,counts = cluster(npc,radius=5)
big_npc = clusters[np.argmax(counts)]

highlight = np.zeros_like(minimap,dtype='uint8')
if len(bank):
    highlight[bank[:,1],bank[:,0]] = [255,0,0]
highlight[npc[:,1],npc[:,0]] = [0,0,255]
highlight[big_npc[:,1],big_npc[:,0]] = [0,255,0]

Image.fromarray(highlight)
```

The `srbot.algorithm` module contains other methods for manipulating sets of points, including sorting/filtering by distance.
These are critical for more complicated objectives.

{{< figure src="/images/rs_bankers.png" class="rightsmall" caption="A diagnostic view of an algorithm to find bankers near the South side of the bank (magenta) based on their proximity to a particular room (cyan), also showing the identification of certain nearby roads (green,red)." >}}
{{< figure src="/images/rs_annoying_rock.png" class="rightsmall" caption="A diagnostic view of an algorithm to find rocks within a mine (shown in green) while excluding one nearby distraction that is exactly the same (red), besides being within the color corresponding to the mine area (blue)." >}}

#### Mainscreen analysis

The techniques used on the minimap are quite applicable to the mainscreen, as well.
The main difference here is that the 3D projection onto 2D means that apparent area and distance is no longer a good invariant. 
This can be mitigated to some extent, since the orientation of the camera can be adjusted to give a nominally top-down view.
The difference can be made up by allowing tolerances on areas and distances. 

Since the 3D world is much more complicated than the 2D minimap, and it is the primary means of interacting with objects, the object identification algorithms here are much more exciting.
The techniques all boil down to identifying pixels that match certain colors, clustering those sets, and filtering by size and distance to other sets.
Some examples of this are shown in the following images.

{{< figure src="/images/rs_agility_tree.png" class="center" caption="On the Tree Gnome Agility course, one has to click agility obstacles. Up next here is a particular tree that is positioned sneakily among other wooden things." >}}
{{< figure src="/images/rs_agility_tree_diagnostic.png" class="center" caption="The tree is unique in having a particular brown color (blue) that is nearby (green) another grayish color (red) regardless of how the camera is rotated." >}}

{{< figure src="/images/rs_ladder.png" class="center" caption="In the Mining Guild mine, everything is shades of brown. If you want to leave the guild, you have to find the particular browns that are either in the shape or color of the ladder. Guess which one I'll use?" >}}
{{< figure src="/images/rs_ladder_diagnostic.png" class="center" caption="A three-way coincidence of colors (red, green, blue channels set high) occurring within a certain radius uniquely identifies the ladder (yellow)" >}}

{{< figure src="/images/rs_air_alter.png" class="center" caption="Jagex probably thought they were being really clever putting several non-functional rocks around the Air rune altar portal." >}}
{{< figure src="/images/rs_air_alter_diagnostic.png" class="center" caption="Fortunately, using a medium-distance clustering of a single unique color, the big one sticks out clearly." >}}

### Color comparison 

I've referenced color tolerance in the previous sections several times, and it should be clear that the `find_colors` method in `srbot.color` is the workhorse of this automation endeavor. 
Colors, as mentioned, are tuples, or vectors, of three bytes representing the red, green, and blue intensity.
$$ \vec{C} = (R,G,B) $$
Building off what was historically done in SCAR and Simba, `srbot` three ways for comparing color:
* RGB difference, which compares $|\vec{C}_1 - \vec{C}_2|$ and is quite fast.
* RGB distance, which compares $\sqrt{\vec{C}_1 \cdot \vec{C}_2}$ and is a bit slower, but closer to "perceptually similar" than a simple difference.
* HSL difference, which first converts both colors to the [HSL color space](https://en.wikipedia.org/wiki/HSL_and_HSV) and checks that difference between hue, saturation, and lightness are within some value for the two colors. Hue is compared as a [ring](https://en.wikipedia.org/wiki/Ring_(mathematics)) (i.e. where the minimum and maximum value are adjacent because the hue wraps back around) using the shortest distance on the ring. Because it involves a conversion, this is much slower, but is closer to 'perceptually similar' than the other options.

The `find_colors` method can use any of these options, with configurable tolerances, to return a list of pixel locations in an image corresponding to colors that meet the criteria.
The bitmap matching routines use these same comparison methods.
I've found that there is no global-best tolerance or method, and that each situation should evaluate what is best.
That said, generally speaking the HSL method is quite robust to the periodic color shifting on the minimap, while RGB distance works well enough for both the mainscreen and inventory.

### Generic script structure

There are two schools of thought on how best to structure an automation routine:
* A "top down" approach where the algorithm analyzes the game state starting from no assumptions and decides what the best action is. This would be analogous to a person with amnesia (no memory of prior actions) playing the game.
* A "sequential" approach where the algorithm bases its next action primarily on what it did last, perhaps to the extent of having to start in a particular state. This is a smarter version of the ancient mouse-replay automation techniques.

The "top down" approach can more gracefully deal with events happening out-of-order at the cost of requiring a robust game-state-detection routine run before every action.
The "sequential" approach is simpler to sketch out, but can get horribly lost in the event of something going wrong, and without logic to correct itself, these errors will grow with time.
The reality is a combination of the two approaches is best, but I tend towards the "top down" approach combined with some minimal state information.

A general outline for a script is an infinite loop that performs the following things.
1. Figure out what the player should be doing by checking high level things: are we logged in, is there a random event, what should we be doing next?
2. Separate branches of code to handle the high level state. E.G. if inventory is empty / have none of what we need, we should be going to get more resources.
3. Continue this branching as a [decision tree](https://en.wikipedia.org/wiki/Decision_tree) until a decision is made about what to do next. E.G. inventory is empty, but not at the mine, so should walk to the mine. Currently on a road somewhere, and should follow it south until we see the mine: so follow the road south.
4. Perform the action in as short a sequence as possible. E.G. if we're in the mine, and inventory is not full, try to mine one rock.
5. After the short sequence of actions is complete, perform another iteration of the main loop.

The python files and Jupyter notebooks in the [srbot repository](https://github.com/BenLand100/srbot) contain many example scripts created in this fashion.

## An example: mining in the Mining Guild

To bring this post to a close, and test Hugo's ability to embed YouTube videos, I've recorded one loop of the [Mining Guild miner](https://github.com/BenLand100/srbot/blob/master/MiningGuildMiner.py) to give an idea of how this style of automation plays the game.
To actually run these scripts, I use `vncserver` from [TigerVNC](https://tigervnc.org/) to create a virtual desktop, e.g. `:2` where I open the RuneScape client. 
Then in any shell I simply set the `DISPLAY` environment variable appropriately, and launch the Python script of my choosing.
PyAutoGUI is smart enough to attach to the [X11](https://en.wikipedia.org/wiki/X_Window_System) server in the VNC session to obtain screenshots and control of the virtual mouse and keyboard. 
For rapid prototyping, it's possible to do the same with a [Jupyter](https://jupyter.org/) notebook, and indeed the srbot repository has several examples of this.
Jupyter provides a very nice GUI frontend to Python development, which honestly is years (decades?) ahead of the UI provided by SCAR/Simba.

{{< youtube_aspect O5jQRFBdFNo 64 >}}
