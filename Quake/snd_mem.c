/*
Copyright (C) 1996-2001 Id Software, Inc.
Copyright (C) 2010-2011 O. Sezer <sezero@users.sourceforge.net>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
// snd_mem.c: sound caching

#include "quakedef.h"

static int getsamplefromfile(byte *data, int inwidth, int srcsample)
{
	if (inwidth == 2)
		return LittleShort ( ((short *)data)[srcsample] );
	else
		return (int)( (unsigned char)(data[srcsample]) - 128) << 8;
}

static int getsample(byte *data, int inwidth, int srcsample)
{
	if (inwidth == 2)
		return ((short *)data)[srcsample];
	else
		return (int)(((signed char *)data)[srcsample]) << 8;
}

static void putsample(byte *data, int outwidth, int i, int sample)
{
	if (outwidth == 2)
		((short *)data)[i] = sample;
	else
		((signed char *)data)[i] = sample >> 8;
}


/*
================
ResampleSfx
================
*/
static void ResampleSfx (sfx_t *sfx, int inrate, int inwidth, byte *data)
{
	int		incount, outcount;
	float	stepscale, samplefrac;
	int		i;
	int		sample;
	sfxcache_t	*sc;

	sc = (sfxcache_t *) Cache_Check (&sfx->cache);
	if (!sc)
		return;

	stepscale = (float)inrate / shm->speed;	// this is usually 0.5, 1, or 2

	incount = sc->length;
	outcount = sc->length / stepscale;
	sc->length = outcount;
	if (sc->loopstart != -1)
		sc->loopstart = sc->loopstart / stepscale;

	sc->speed = shm->speed;
	if (loadas8bit.value)
		sc->width = 1;
	else
		sc->width = 2;
	sc->stereo = 0;

// resample / decimate to the current source rate

	if (stepscale == 1 && inwidth == 1 && sc->width == 1)
	{
// fast special case
		for (i = 0; i < outcount; i++)
			((signed char *)sc->data)[i] = (int)( (unsigned char)(data[i]) - 128);
	}
	else
	{
		if (stepscale < 1)
		{
// upsampling
			
			// linearly interpolate between the two closest source samples.
			// this alone sounds much better than id's method, but still produces
			// high-frequency junk.
			
			for (i = 0, samplefrac = 0; i < outcount; i++, samplefrac += stepscale)
			{	
				int srcsample1 = CLAMP(0, floor(samplefrac), incount - 1);
				int srcsample2 = CLAMP(0, ceil(samplefrac), incount - 1);				
				
				// how far between the samples. in [0, 1].
				float mu = samplefrac - floor(samplefrac);

				float srcsample1weight = 1 - mu;		
				float srcsample2weight = mu;

				sample = (srcsample1weight * getsamplefromfile(data, inwidth, srcsample1))
						  + (srcsample2weight * getsamplefromfile(data, inwidth, srcsample2));
				putsample(sc->data, sc->width, i, sample);
			}

			// box filter
			
			// box_half_width is the number of samples on each side of a given sample
			// that are averaged together. 
			// for 44100Hz output, a box width of 5 (i.e. a box_half_width of 2) seems
			// to sound the best
			const int box_half_width = CLAMP(0, sc->speed / 22050, 4);
			
			if (box_half_width > 0)
			{
				const int box_width = (2 * box_half_width) + 1;
				int history[box_half_width];
				memset(history, 0, sizeof(history));
				int box_sum = 0;
				for (i = 0; i < (outcount + box_half_width); i++)
				{	
					// calculate the new sample we will write
					const int sample_at_i = getsample(sc->data, sc->width, CLAMP(0, i, outcount - 1));					
					box_sum += sample_at_i;
					box_sum -= history[0];
					const int newsample = box_sum / box_width;
					
					// shift the entries in the history buffer left, discarding the entry
					// at history[0] and leaving a space at history[box_half_width-1]
					int j;
					for (j=0; j<(box_half_width-1); j++)
					{
						history[j] = history[j+1];
					}
					
					// save the sample we are going to overwrite at history[box_half_width-1]
					const int write_loc = i - box_half_width;
					history[box_half_width-1] = getsample(sc->data, sc->width, CLAMP(0, write_loc, outcount - 1));
					
					// only write the new sample if it lies within the bounds of the output array
					if (write_loc >= 0 && write_loc < outcount)
					{
						putsample(sc->data, sc->width, write_loc, newsample);
					}
				}
			}
		}
		else
		{
// general case / downsampling
			for (i = 0, samplefrac = 0; i < outcount; i++, samplefrac += stepscale)
			{	
				sample = getsamplefromfile(data, inwidth, (int)samplefrac);
				putsample(sc->data, sc->width, i, sample);
			}
		}
	}
}

//=============================================================================

/*
==============
S_LoadSound
==============
*/
sfxcache_t *S_LoadSound (sfx_t *s)
{
	char	namebuffer[256];
	byte	*data;
	wavinfo_t	info;
	int		len;
	float	stepscale;
	sfxcache_t	*sc;
	byte	stackbuf[1*1024];		// avoid dirtying the cache heap

// see if still in memory
	sc = (sfxcache_t *) Cache_Check (&s->cache);
	if (sc)
		return sc;

//	Con_Printf ("S_LoadSound: %x\n", (int)stackbuf);

// load it in
	q_strlcpy(namebuffer, "sound/", sizeof(namebuffer));
	q_strlcat(namebuffer, s->name, sizeof(namebuffer));

//	Con_Printf ("loading %s\n",namebuffer);

	data = COM_LoadStackFile(namebuffer, stackbuf, sizeof(stackbuf), NULL);

	if (!data)
	{
		Con_Printf ("Couldn't load %s\n", namebuffer);
		return NULL;
	}

	info = GetWavinfo (s->name, data, com_filesize);
	if (info.channels != 1)
	{
		Con_Printf ("%s is a stereo sample\n",s->name);
		return NULL;
	}

	if (info.width != 1 && info.width != 2)
	{
		Con_Printf("%s is not 8 or 16 bit\n", s->name);
		return NULL;
	}

	stepscale = (float)info.rate / shm->speed;
	len = info.samples / stepscale;

	len = len * 2 * info.channels;

	if (info.samples == 0 || len == 0)
	{
		Con_Printf("%s has zero samples\n", s->name);
		return NULL;
	}

	sc = (sfxcache_t *) Cache_Alloc ( &s->cache, len + sizeof(sfxcache_t), s->name);
	if (!sc)
		return NULL;

	sc->length = info.samples;
	sc->loopstart = info.loopstart;
	sc->speed = info.rate;
	sc->width = info.width;
	sc->stereo = info.channels;

	ResampleSfx (s, sc->speed, sc->width, data + info.dataofs);

	return sc;
}



/*
===============================================================================

WAV loading

===============================================================================
*/

static byte	*data_p;
static byte	*iff_end;
static byte	*last_chunk;
static byte	*iff_data;
static int	iff_chunk_len;

static short GetLittleShort (void)
{
	short val = 0;
	val = *data_p;
	val = val + (*(data_p+1)<<8);
	data_p += 2;
	return val;
}

static int GetLittleLong (void)
{
	int val = 0;
	val = *data_p;
	val = val + (*(data_p+1)<<8);
	val = val + (*(data_p+2)<<16);
	val = val + (*(data_p+3)<<24);
	data_p += 4;
	return val;
}

static void FindNextChunk (const char *name)
{
	while (1)
	{
	// Need at least 8 bytes for a chunk
		if (last_chunk + 8 >= iff_end)
		{
			data_p = NULL;
			return;
		}

		data_p = last_chunk + 4;
		iff_chunk_len = GetLittleLong();
		if (iff_chunk_len < 0 || iff_chunk_len > iff_end - data_p)
		{
			data_p = NULL;
			Con_DPrintf("bad \"%s\" chunk length (%d)\n", name, iff_chunk_len);
			return;
		}
		last_chunk = data_p + ((iff_chunk_len + 1) & ~1);
		data_p -= 8;
		if (!Q_strncmp((char *)data_p, name, 4))
			return;
	}
}

static void FindChunk (const char *name)
{
	last_chunk = iff_data;
	FindNextChunk (name);
}

#if 0
static void DumpChunks (void)
{
	char	str[5];

	str[4] = 0;
	data_p = iff_data;
	do
	{
		memcpy (str, data_p, 4);
		data_p += 4;
		iff_chunk_len = GetLittleLong();
		Con_Printf ("0x%x : %s (%d)\n", (int)(data_p - 4), str, iff_chunk_len);
		data_p += (iff_chunk_len + 1) & ~1;
	} while (data_p < iff_end);
}
#endif

/*
============
GetWavinfo
============
*/
wavinfo_t GetWavinfo (const char *name, byte *wav, int wavlength)
{
	wavinfo_t	info;
	int	i;
	int	format;
	int	samples;

	memset (&info, 0, sizeof(info));

	if (!wav)
		return info;

	iff_data = wav;
	iff_end = wav + wavlength;

// find "RIFF" chunk
	FindChunk("RIFF");
	if (!(data_p && !Q_strncmp((char *)data_p + 8, "WAVE", 4)))
	{
		Con_Printf("%s missing RIFF/WAVE chunks\n", name);
		return info;
	}

// get "fmt " chunk
	iff_data = data_p + 12;
#if 0
	DumpChunks ();
#endif

	FindChunk("fmt ");
	if (!data_p)
	{
		Con_Printf("%s is missing fmt chunk\n", name);
		return info;
	}
	data_p += 8;
	format = GetLittleShort();
	if (format != WAV_FORMAT_PCM)
	{
		Con_Printf("%s is not Microsoft PCM format\n", name);
		return info;
	}

	info.channels = GetLittleShort();
	info.rate = GetLittleLong();
	data_p += 4 + 2;
	info.width = GetLittleShort() / 8;

// get cue chunk
	FindChunk("cue ");
	if (data_p)
	{
		data_p += 32;
		info.loopstart = GetLittleLong();
	//	Con_Printf("loopstart=%d\n", sfx->loopstart);

	// if the next chunk is a LIST chunk, look for a cue length marker
		FindNextChunk ("LIST");
		if (data_p)
		{
			if (!strncmp((char *)data_p + 28, "mark", 4))
			{	// this is not a proper parse, but it works with cooledit...
				data_p += 24;
				i = GetLittleLong();	// samples in loop
				info.samples = info.loopstart + i;
		//		Con_Printf("looped length: %i\n", i);
			}
		}
	}
	else
		info.loopstart = -1;

// find data chunk
	FindChunk("data");
	if (!data_p)
	{
		Con_Printf("%s is missing data chunk\n", name);
		return info;
	}

	data_p += 4;
	samples = GetLittleLong() / info.width;

	if (info.samples)
	{
		if (samples < info.samples)
			Sys_Error ("%s has a bad loop length", name);
	}
	else
		info.samples = samples;

	info.dataofs = data_p - wav;

	return info;
}

