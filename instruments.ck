//----------------------------------------------------------------------------
/*  Multi-instrumenter by Andrew Lee
    
    source code and wekinator provided by Ge Wang (2023) and Rebecca 
    Fiebrink (2009-2015)
    
    USAGE: This example receives Wekinator "/wek/outputs/" messages
    over OSC and maps incoming parameters to musical parameters;
    This example is designed to run with a sender, which can be:
    1) the Wekinator application, OR
    2) another Chuck/ChAI program containing a Wekinator object
    
    This example expects to receive 8 continuous parameters in the
    range [0,1]; these parameters are mapped to musical parameters
    in map2sound().

    This example is "always on" -- no note triggering with keyboard
    
    expected parameters for this class are:
    0,1 = top left instrument's volume and frequency
    2,3 = top right instrument's volume and frequency
    4,5 = bottom left instrument's volume and frequency
    6,7 = bottom right instrument's volume and frequency */
//----------------------------------------------------------------------------

// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

// listen for "/wek/output" message with 5 floats coming in
oscin.addAddress( "/wek/outputs, ffffffff" );
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 8 continuous parameters...", "" >>>; 

// synthesis 4 instruments
Bowed topleft => Gain g_topleft => dac;  // violin
BlowHole topright => Gain g_topright => dac;  // clarinet
Brass bottomleft => Gain g_bottomleft => dac;  // brass
Flute bottomright => Gain g_bottomright => dac;  // flute

// set defaults 
0.5 => g_topleft.gain;
72 => Std.mtof => topleft.freq;
0.5 => g_topright.gain;
68 => Std.mtof => topright.freq;
0.5 => g_bottomleft.gain;
64 => Std.mtof => bottomleft.freq;
0.5 => g_bottomright.gain;
60 => Std.mtof => bottomright.freq;


// expecting 8 output dimensions
8 => int NUM_PARAMS;
float myParams[NUM_PARAMS];

// envelopes for smoothing parameters
// (alternately, can use slewing interpolators; SEE:
// https://chuck.stanford.edu/doc/examples/vector/interpolate.ck)
Envelope envs[NUM_PARAMS];
for( 0 => int i; i < NUM_PARAMS; i++ )
{
    envs[i] => blackhole;
    .5 => envs[i].value;
    10::ms => envs[i].duration;
}

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void setParams( float params[] )
{
    // make sure we have enough
    if( params.size() >= NUM_PARAMS )
    {		
        // adjust the synthesis accordingly
        0.0 => float x;
        for( 0 => int i; i < NUM_PARAMS; i++ )
        {
            // get value
            params[i] => x;
            // clamp it
            if( x < 0 ) 0 => x;
            if( x > 1 ) 1 => x;
            // set as target of envelope (for smoothing)
            x => envs[i].target;
            // remember
            x => myParams[i];
        }
    }
}

// function to map incoming parameters to musical parameters
fun void map2sound()
{
    // time loop
    while( true )
    {
        // FYI envs[i] are used for smoothing param values
        // top left
        envs[0].value() => g_topleft.gain;
        envs[1].value() * 100 + 20 => Std.mtof => topleft.freq;
        // top right
        envs[2].value() => g_topright.gain;
        envs[3].value() * 100 + 20 => Std.mtof => topright.freq;
        // bottom left
        envs[4].value() => g_bottomleft.gain;
        envs[5].value() * 100 + 20 => Std.mtof => bottomleft.freq;
        // bottom right
        envs[6].value() => g_bottomright.gain;
        envs[7].value() * 100 + 20 => Std.mtof => bottomright.freq;
        
        // time
        10::ms => now;
    }
}

// turn volume off!
fun void soundOff()
{
    topleft.noteOff;
    topright.noteOff;
    bottomleft.noteOff;
    bottomright.noteOff;
}

// turn volume on!
fun void soundOn()
{
    //<<< "SOUUUUUUUND">>>;
    0.8 => topleft.startBowing;  // top left
    0.8 => topleft.noteOn;
    0.8 => topright.startBlowing; // top right
    0.8 => topright.noteOn;
    0.8 => bottomleft.startBlowing; // bottom left
    0.8 => bottomleft.noteOn;
    0.8 => bottomright.startBlowing;  // bottom right
    0.8 => bottomright.noteOn;
    
}	

fun void waitForEvent()
{
    // array to hold params
    float p[NUM_PARAMS];

    // infinite event loop
    while( true )
    {
        // wait for OSC message to arrive
        oscin => now;

        // grab the next message from the queue. 
        while( oscin.recv(msg) )
        {
            // print stuff
            cherr <= msg.address <= " ";
            
            // unpack our 5 floats into our array p
            for( int i; i < NUM_PARAMS; i++ )
            {
                // put into array
                msg.getFloat(i) => p[i];
                // print
                cherr <= p[i] <= " ";
            }
            
            // print
            cherr <= IO.newline();
            
            // set the parameters
            setParams( p );
        }
    }
}

// spork osc receiver loop
spork ~waitForEvent();
// spork mapping function
spork ~ map2sound();	
// turn on sound
soundOn();

// time loop to keep everything going
while( true ) 1::second => now;
