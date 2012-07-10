#import <CoreAudio/CoreAudio.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

void getDevices()
{
	unsigned i;
    unsigned dev_count;
    AudioObjectPropertyAddress addr;
    AudioDeviceID *dev_ids;
    UInt32 buf_size, dev_size, size = sizeof(AudioDeviceID);
    AudioBufferList *buf = NULL;
    OSStatus ostatus;

    /* Find out how many audio devices there are */
    addr.mSelector = kAudioHardwarePropertyDevices;
    addr.mScope = kAudioObjectPropertyScopeGlobal;
    addr.mElement = kAudioObjectPropertyElementMaster;
    ostatus = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr,
                                             0, NULL, &dev_size);
    if (ostatus != noErr) 
    {
		dev_size = 0;
    }

    /* Calculate the number of audio devices available */
    dev_count = dev_size / size;
    if (dev_count==0) 
    {
	  	printf("Core Audio found no sound devices\n");
	  	/* Enabling this will cause pjsua-lib initialization to fail when
	  	 * there is no sound device installed in the system, even when pjsua
	  	 * has been run with --null-audio. Moreover, it might be better to
	  	 * think that the core audio backend initialization is successful,
	  	 * regardless there is no audio device installed, as later application
	  	 * can check it using get_dev_count().
	  	return PJMEDIA_EAUD_NODEV;
	  	 */
	  	return;
    }
    printf("Core Audio detected %d devices\n", dev_count);

    /* Get all the audio device IDs */
    dev_ids = (AudioDeviceID *)malloc(dev_size * size);
    if (!dev_ids)
    {
    	printf("Couldnt alloc memory\n");
		return;
	}

	memset(dev_ids, 0, dev_size * size);
    ostatus = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr,
					 0, NULL,
			         &dev_size, (void *)dev_ids);
    
    if (ostatus != noErr ) 
    {
		/* This should not happen since we have successfully retrieved
		 * the property data size before
		 */
		printf("AudioObjectGetPropertyData failed with %d\n", ostatus);
		return;
    }

    for (int ii = 0; ii < dev_count; ii++)
    {
    	printf("Device %d (%d) present!\n", ii, dev_ids[ii]);
    }
    
	if (dev_size > 1) 
	{
		AudioDeviceID dev_id = kAudioObjectUnknown;
		unsigned idx = 0;
		
		/* Find default audio input device */
		addr.mSelector = kAudioHardwarePropertyDefaultInputDevice;
		addr.mScope = kAudioObjectPropertyScopeGlobal;
		addr.mElement = kAudioObjectPropertyElementMaster;
		size = sizeof(dev_id);
		
		ostatus = AudioObjectGetPropertyData(kAudioObjectSystemObject,
						     &addr, 0, NULL,
						     &size, (void *)&dev_id);

		if (ostatus == noErr && dev_id != dev_ids[idx]) 
		{
		    AudioDeviceID temp_id = dev_ids[idx];
	        printf("*** [input] temp_id: %d, idx: %d, dev_id: %d\n", temp_id, idx, dev_id);
		    
		    for (i = idx + 1; i < dev_size; i++) 
		    {
				if (dev_ids[i] == dev_id) 
				{
		            printf("*** [input] swap: i=%d\n", i);
				    dev_ids[idx++] = dev_id;
				    dev_ids[i] = temp_id;
				    break;
				}
		    }
		}
		else 
		{
	        printf("*** [input] FAILED to get Default Input Device! status: %d, dev_id: %d, dev_ids[idx]: %d, idx: %d\n", ostatus, dev_id, dev_ids[idx], idx);
	        if (ostatus == noErr)
	        	idx++;
	    }

		/* Find default audio output device */
		addr.mSelector = kAudioHardwarePropertyDefaultOutputDevice;	
		ostatus = AudioObjectGetPropertyData(kAudioObjectSystemObject,
						     &addr, 0, NULL,
						     &size, (void *)&dev_id);

		if (ostatus == noErr && dev_id != dev_ids[idx]) 
		{
		    AudioDeviceID temp_id = dev_ids[idx];
		    printf("*** [output] temp_id: %d, idx: %d, dev_id: %d\n", temp_id, idx, dev_id);
		    
		    for (i = idx + 1; i < dev_size; i++) 
		    {
				if (dev_ids[i] == dev_id) 
				{
					printf("*** [output] swap: i=%d\n", i);
				    dev_ids[idx] = dev_id;
				    dev_ids[i] = temp_id;
				    break;
				}
		    }
		}
		else 
		{
	        printf("*** [input] FAILED to get Default Output Device! status: %d, dev_id: %d, dev_ids[idx]: %d, idx: %d\n", ostatus, dev_id, dev_ids[idx], idx);
	    }
	}

	buf_size = 0;
    for (i = 0; i < dev_count; i++) 
	{
		Float64 sampleRate;
		/* Get device name */
		addr.mSelector = kAudioDevicePropertyDeviceName;
		addr.mScope = kAudioObjectPropertyScopeGlobal;
		addr.mElement = kAudioObjectPropertyElementMaster;
		char name[256];
		AudioObjectID dev_id2 = dev_ids[i];;
		int default_samples_per_sec;

		size = sizeof(name);
		AudioObjectGetPropertyData(dev_id2, &addr,
					   0, NULL,
				           &size, (void *)name);

	        /* Get the number of input channels */
		addr.mSelector = kAudioDevicePropertyStreamConfiguration;
		addr.mScope = kAudioDevicePropertyScopeInput;
		size = 0;
		ostatus = AudioObjectGetPropertyDataSize(dev_id2, &addr,
		                                         0, NULL, &size);

		int input_count = 0;

		if (ostatus == noErr && size > 0) 
		{

		    if (size > buf_size) 
		    {
				buf = (AudioBufferList *)malloc(size);
				buf_size = size;
		    }
		    if (buf) 
		    {
				UInt32 idx;

				/* Get the input stream configuration */
				ostatus = AudioObjectGetPropertyData(dev_id2, &addr,
								     0, NULL,
								     &size, buf);
				if (ostatus == noErr) {
				    /* Count the total number of input channels in
				     * the stream
				     */
				    for (idx = 0; idx < buf->mNumberBuffers; idx++) 
				    {
						input_count += buf->mBuffers[idx].mNumberChannels;
				    }
				}
		    }
		}

	        /* Get the number of output channels */

		int output_count = 0;
		addr.mScope = kAudioDevicePropertyScopeOutput;
		size = 0;
		ostatus = AudioObjectGetPropertyDataSize(dev_id2, &addr,
		                                         0, NULL, &size);
		if (ostatus == noErr && size > 0) 
		{

		    if (size > buf_size) 
		    {
				buf = (AudioBufferList *)malloc(size);
				buf_size = size;
		    }
		    if (buf) 
		    {
				UInt32 idx;

				/* Get the output stream configuration */
				ostatus = AudioObjectGetPropertyData(dev_id2, &addr,
								     0, NULL,
								     &size, buf);
				if (ostatus == noErr)
				{
				    /* Count the total number of output channels in
				     * the stream
				     */
				    for (idx = 0; idx < buf->mNumberBuffers; idx++) 
				    {
						output_count += buf->mBuffers[idx].mNumberChannels;
				    }
				}
		    }
		}

		/* Get default sample rate */
		addr.mSelector = kAudioDevicePropertyNominalSampleRate;
		addr.mScope = kAudioObjectPropertyScopeGlobal;
		size = sizeof(Float64);
		ostatus = AudioObjectGetPropertyData (dev_id2, &addr,
			                              0, NULL,
			                              &size, &sampleRate);
		default_samples_per_sec = (ostatus == noErr ? sampleRate : 16000);

		printf(" dev_id %d(%d): %s  (in=%d, out=%d) %dHz\n",
		       i,
		       dev_ids[i],
		       name,
		       input_count,
		       output_count,
		       default_samples_per_sec);
	}
}

int main(int argc, char const *argv[])
{
	getDevices();
	return 0;
}
