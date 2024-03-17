//------------
// locations.c
//------------
// Original format by JP Grossman for Proquake -- woods / rook #pqteam

#include "quakedef.h"

#define VectorSet(v, x, y, z) ((v)[0] = (x), (v)[1] = (y), (v)[2] = (z))
#define VectorClear(a) ((a)[0] = (a)[1] = (a)[2] = 0)

location_t	*locations, *temploc;

extern	cvar_t	r_drawlocs;

void LOC_PQ_Init (void) // woods added PQ to name #pqteam
{
	temploc = Z_Malloc(sizeof(location_t));
	locations = Z_Malloc(sizeof(location_t));
}

void LOC_Delete(location_t* loc)
{
	location_t** ptr, ** next;
	for (ptr = &locations; *ptr; ptr = next)
	{
		next = &(*ptr)->next_loc;
		if (*ptr == loc)
		{
			*ptr = loc->next_loc;
			Z_Free(loc);
		}
	}
}

void LOC_Clear_f (void)
{
	location_t *l;
	for (l = locations;l;l = l->next_loc)
	{
		LOC_Delete(l);
	}
}

void LOC_SetLoc (vec3_t mins, vec3_t maxs, char *name)
{
	location_t *l, **ptr;
	int namelen;
	float	temp;
	int		n;
	vec_t	sum;

	if (!(name))
		return;

	namelen = strlen(name);
	l = Z_Malloc(sizeof(location_t));

	sum = 0;
	for (n = 0 ; n < 3 ; n++)
	{
		if (mins[n] > maxs[n])
		{
			temp = mins[n];
			mins[n] = maxs[n];
			maxs[n] = temp;
		}
		sum += maxs[n] - mins[n];
	}
	
	l->sum = sum;

	VectorSet(l->mins, mins[0], mins[1], mins[2]-32);	//ProQuake Locs are extended +/- 32 units on the z-plane...
	VectorSet(l->maxs, maxs[0], maxs[1], maxs[2]+32);
	q_snprintf (l->name, namelen + 1, "%s", name);
	Con_DPrintf("Location %s assigned.\n", name);
	for (ptr = &locations;*ptr;ptr = &(*ptr)->next_loc);
	*ptr = l; // woods remove indent
}

qboolean nqloc; // woods nq/qw 3/6-point format flag #qwlocs
qboolean hasPrintedFormat = false; // woods #qwlocs

qboolean LOC_LoadLocations (void) // woods #qwlocs
{
    char	filename[MAX_OSPATH];
    vec3_t	mins, maxs;
    char	name[64]; // incrrased from 32 to 64 for qw locs

    int		i, linenumber, limit, len;
    char	*filedata, *text, *textend, *linestart, *linetext, *lineend;
    int		filesize;

    hasPrintedFormat = false;

    if (cls.state != ca_connected || !cl.worldmodel)
    {
        Con_Printf("!LOC_LoadLocations ERROR: No map loaded!\n");
        return false;
    }

    //LOC_Init();

    LOC_Clear_f();

    q_snprintf(filename, sizeof(filename), "locs/%s.loc", cl.mapname);

    if (COM_FileExists(filename, NULL) == false)
    {
        //Con_Printf("%s could not be found.\n", filename);
        return false;
    }

    filedata = (char*)COM_LoadTempFile(filename, NULL);

    if (!filedata)
    {
        Con_Printf("%s contains empty or corrupt data.\n", filename);
        return false;
    }

    filesize = strlen(filedata);

    text = filedata;
    textend = filedata + filesize;
    for (linenumber = 1;text < textend;linenumber++)
    {
        linestart = text;
        for (;text < textend && *text != '\r' && *text != '\n';text++)
            ;
        lineend = text;
        if (text + 1 < textend && *text == '\r' && text[1] == '\n')
            text++;
        if (text < textend)
            text++;
        // trim trailing whitespace
        while (lineend > linestart && lineend[-1] <= ' ')
            lineend--;
        // trim leading whitespace
        while (linestart < lineend && *linestart <= ' ')
            linestart++;
        // check if this is a comment
        if (linestart + 2 <= lineend && !strncmp(linestart, "//", 2))
            continue;
        linetext = linestart;
        limit = 3; // Assume a 3-point format initially
       
        for (i = 0;i < limit && linetext < lineend;i++) // detect 3 or 6 point format using commas, qw 3 point system has no commas
        {
            char* nextCommaOrSpace = linetext;
            while (nextCommaOrSpace < lineend && *nextCommaOrSpace != ',' && *nextCommaOrSpace > ' ')
                nextCommaOrSpace++;

            if (*nextCommaOrSpace == ',')
            {
                nqloc = true;
                if (!hasPrintedFormat)
                {
                    Con_DPrintf("NetQuake LOC Detected\n");
                    hasPrintedFormat = true;
                }
            }
            else
            {
				nqloc = false;
                if (!hasPrintedFormat)
                {
                    Con_DPrintf("QuakeWorld LOC Detected\n");
                    hasPrintedFormat = true;
                }
			}

            if (i < 3) mins[i] = atof(linetext); // Use mins for initial coordinates

            linetext = nextCommaOrSpace;
            if (*nextCommaOrSpace == ',') linetext++;

            while (linetext < lineend && *linetext <= ' ') linetext++;
        }

        if (nqloc) // Detected a 6-point format
        {
            limit = 6; // Adjust limit for parsing 6-point data
            for (; i < limit && linetext < lineend; i++)
            {
                char* nextCommaOrSpace = linetext;
                while (nextCommaOrSpace < lineend && *nextCommaOrSpace != ',' && *nextCommaOrSpace > ' ')
                    nextCommaOrSpace++;

                if (i >= 3) maxs[i - 3] = atof(linetext); // Use maxs for additional coordinates

                linetext = nextCommaOrSpace;
                if (*nextCommaOrSpace == ',') linetext++;

                while (linetext < lineend && *linetext <= ' ') linetext++;
            }
        }

        // Now, extract the name for both formats here
        while (linetext < lineend && *linetext <= ' ') linetext++;
        len = q_min(lineend - linetext, sizeof(name) - 1);
        memcpy(name, linetext, len);
        name[len] = '\0';

        if (nqloc && i == 6) // Successfully parsed a 6-point format
        {

            size_t nameLen = strlen(name);
            if (name[0] == '"' && name[nameLen - 1] == '"') {
                name[nameLen - 1] = '\0';
                memmove(name, name + 1, nameLen - 1);
            }

            LOC_SetLoc(mins, maxs, name);
        }
        else if (!nqloc && i == 3) // Successfully parsed a 3-point format
        {
            char* separator;
            while ((separator = strstr(name, "$loc_name_separator")) != NULL)
            {
                *separator = '-'; // Replace the separator with "-"

                char* restOfString = separator + strlen("$loc_name_separator");
                memmove(separator + 1, restOfString, strlen(restOfString) + 1);
            }

            char* locNameInstance;
            while ((locNameInstance = strstr(name, "$loc_name_")) != NULL) 
            {
                size_t prefixLength = strlen("$loc_name_"); // remove the prefix
                memmove(locNameInstance, locNameInstance + prefixLength, strlen(locNameInstance + prefixLength) + 1);
            }

            char* dollarDot;
            while ((dollarDot = strstr(name, "$.")) != NULL) 
            {
                *dollarDot = '-'; // Replace "$." with "-"
                memmove(dollarDot + 1, dollarDot + 2, strlen(dollarDot + 2) + 1); // +1 for null terminator
            }
            
            LOC_SetLoc(mins, mins, name);
        }
        else
            Con_DPrintf("Error parsing location data on line %d.\n", linenumber);
    }
    return true;
}

char *LOC_GetLocation (vec3_t p) // woods #qwlocs
{
    location_t *loc;
    location_t *bestloc;
    float dist, bestdist;

    bestloc = NULL;

    bestdist = 999999;

    vec3_t diff;

    for (loc = locations;loc;loc = loc->next_loc) 
    {
        if (!nqloc) // qw nearest point location
        {
            vec3_t scaled_mins;
            VectorCopy(loc->mins, scaled_mins);
            for (int i = 0; i < 3; i++)
            {
                scaled_mins[i] /= 8.0; // Adjusting the scale of the input coordinates to match the stored locations
            }

            VectorSubtract(p, scaled_mins, diff); // squared distance from the adjusted point to the location point
            dist = diff[0] * diff[0] + diff[1] * diff[1] + diff[2] * diff[2];
        }
        else // nq axial box location: calculate the shortest distance from point to the axial box (rectangular prism)
        {
            dist = fabs(loc->mins[0] - p[0]) + fabs(loc->maxs[0] - p[0]) +
                fabs(loc->mins[1] - p[1]) + fabs(loc->maxs[1] - p[1]) +
                fabs(loc->mins[2] - p[2]) + fabs(loc->maxs[2] - p[2]) - loc->sum;

            if (dist < .01)
            {
                return loc->name;
            }
        }

        if (!bestloc || dist < bestdist) 
        {
            bestdist = dist;
            bestloc = loc;
            ;
        }
    }

    if (bestloc) 
    {
        return bestloc->name;
    }
    return "no .loc";
}
