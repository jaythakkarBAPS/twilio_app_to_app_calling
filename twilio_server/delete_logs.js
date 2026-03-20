require('dotenv').config();
const twilio = require('twilio');

const sid = process.env.TWILIO_ACCOUNT_SID;
const apiKey = process.env.TWILIO_API_KEY_SID;
const apiSecret = process.env.TWILIO_API_KEY_SECRET;

const twilioClient = new twilio(apiKey, apiSecret, { accountSid: sid });

async function deleteAllLogs() {
    console.log('Fetching call logs...');
    try {
        const calls = await twilioClient.calls.list({ limit: 1000 });
        console.log(`Found ${calls.length} calls to delete.`);

        for (const call of calls) {
            try {
                await twilioClient.calls(call.sid).remove();
                console.log(`Deleted call: ${call.sid}`);
            } catch (err) {
                console.error(`Error deleting call ${call.sid}: ${err.message}`);
            }
        }
        console.log('Bulk deletion completed.');
    } catch (error) {
        console.error('Failed to list or delete calls:', error);
    }
}

deleteAllLogs();
