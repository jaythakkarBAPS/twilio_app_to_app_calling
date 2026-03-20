const express = require('express');
const twilio = require('twilio');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(express.urlencoded({ extended: false }));
app.use(express.json());

const AccessToken = twilio.jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;

// --- Token Generation Endpoint ---
// Used by the Flutter app to get a capability token for the client
app.get('/token', (req, res) => {
  const identity = req.query.identity || 'agent_001';
  const platform = req.query.platform || 'ios'; // android or ios
  let pushCredentialSid = process.env.IOS_PUSH_CREDENTIAL_SID;

  if (platform === 'android') {
    pushCredentialSid = process.env.ANDROID_PUSH_CREDENTIAL_SID;
  }
  console.debug('pushCredentialSid', pushCredentialSid)

  const token = new AccessToken(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_API_KEY_SID,
    process.env.TWILIO_API_KEY_SECRET,
    { identity: identity }
  );

  const grant = new VoiceGrant({
    outgoingApplicationSid: process.env.TWILIO_TWIML_APP_SID,
    pushCredentialSid: pushCredentialSid,
    incomingAllow: true,
  });

  token.addGrant(grant);

  res.send({
    identity: identity,
    token: token.toJwt(),
  });
  console.log(`Token generated for identity: ${identity} (${platform})`);
});

// --- Make Call Endpoint ---
// Twilio hits this when TwilioVoice.instance.call.place() is called in Flutter
app.post('/make-call', (req, res) => {
  console.debug('Incoming make-call request:', req.body);
  const twiml = new twilio.twiml.VoiceResponse();
  const to = req.body.To;

  if (to) {
    const dial = twiml.dial({
      callerId: process.env.TWILIO_CALLER_NUMBER,
    });

    // Check if the recipient is a Client (another app user) or a PSTN Number
    if (to.startsWith('client:')) {
      console.debug(`Routing call to client: ${to}`);
      dial.client(to.replace('client:', ''));
    } else {
      console.debug(`Routing call to number: ${to}`);
      dial.number(to);
    }
  } else {
    twiml.say('Thanks for calling!');
  }

  const responseText = twiml.toString();
  console.log('Responding with TwiML:', responseText);
  res.type('text/xml');
  res.send(responseText);
});

// --- Inbound Call Endpoint ---
// Set this as your Twilio Number's Voice URL
app.post('/inbound-call', (req, res) => {
  console.debug('Incoming call request:', req.body);
  console.log(`Routing incoming call from ${req.body.From} to agent_001`);
  const twiml = new twilio.twiml.VoiceResponse();
  const dial = twiml.dial();

  // Route to agent identity, masking the caller ID with "Masked Caller"
  dial.client({
    statusCallbackEvent: 'initiated ringing answered completed',
    statusCallback: `${req.protocol}://${req.get('host')}/call-status`,
  }, 'agent_001').callerId = 'Masked Caller';

  res.type('text/xml');
  res.send(twiml.toString());
});

app.post('/call-status', (req, res) => {
  console.log('Call status update:', req.body);
  res.sendStatus(200);
});

app.listen(port, () => {
  console.log(`Backend server running on port ${port}`);
});
