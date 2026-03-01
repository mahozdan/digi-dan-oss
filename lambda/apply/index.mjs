import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { randomUUID } from 'crypto';

const dynamo = new DynamoDBClient({ region: 'il-central-1' });
const ses = new SESClient({ region: 'il-central-1' });

const TABLE_NAME = process.env.TABLE_NAME || 'community-applications';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || '';
const FROM_EMAIL = process.env.FROM_EMAIL || '';

const CORS_HEADERS = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
};

export const handler = async (event) => {
    if (event.requestContext?.http?.method === 'OPTIONS') {
        return { statusCode: 200, headers: CORS_HEADERS, body: '' };
    }

    try {
        const body = JSON.parse(event.body);
        const formType = body.type || 'hfc_application';

        if (!body.name || !body.email || !body.phone) {
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ error: 'Missing required fields: name, email, phone' }),
            };
        }

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email)) {
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ error: 'Invalid email address' }),
            };
        }

        if (!/^0[2-9]\d{7,8}$/.test(body.phone)) {
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ error: 'Invalid phone number' }),
            };
        }

        if (formType === 'hfc_application') {
            if (!body.israeli_id || !body.role) {
                return {
                    statusCode: 400,
                    headers: CORS_HEADERS,
                    body: JSON.stringify({ error: 'Missing required fields: israeli_id, role' }),
                };
            }
            if (!/^\d{5,9}$/.test(body.israeli_id)) {
                return {
                    statusCode: 400,
                    headers: CORS_HEADERS,
                    body: JSON.stringify({ error: 'Invalid Israeli ID' }),
                };
            }
        }

        const applicationId = randomUUID();
        const timestamp = new Date().toISOString();

        const item = {
            id: { S: applicationId },
            type: { S: formType },
            name: { S: body.name },
            email: { S: body.email },
            phone: { S: body.phone },
            status: { S: 'pending' },
            submitted_at: { S: timestamp },
        };

        if (formType === 'hfc_application') {
            item.israeli_id = { S: body.israeli_id };
            item.role = { S: body.role };
            item.has_existing_app = { S: body.has_existing_app || 'no' };
        }

        await dynamo.send(new PutItemCommand({
            TableName: TABLE_NAME,
            Item: item,
            ConditionExpression: 'attribute_not_exists(id)',
        }));

        if (ADMIN_EMAIL && FROM_EMAIL) {
            const isHfc = formType === 'hfc_application';
            const subjectLabel = isHfc
                ? `[הגשת מועמדות פעה"ע] ${body.name}`
                : `[הקמת קהילת OSS] ${body.name}`;

            const emailLines = isHfc
                ? [
                    `סוג פנייה: הגשת מועמדות — חייל/ת מילואים פיקוד העורף`,
                    ``,
                    `שם: ${body.name}`,
                    `ת.ז.: ${body.israeli_id}`,
                    `אימייל: ${body.email}`,
                    `טלפון: ${body.phone}`,
                    `תפקיד: ${body.role}`,
                    `יש אפליקציה קיימת: ${body.has_existing_app === 'yes' ? 'כן' : 'לא'}`,
                ]
                : [
                    `סוג פנייה: מעוניין/ת להקים קהילת OSS ליחידת מילואים אחרת`,
                    ``,
                    `שם: ${body.name}`,
                    `אימייל: ${body.email}`,
                    `טלפון: ${body.phone}`,
                ];

            emailLines.push(``, `מזהה בקשה: ${applicationId}`, `הוגש: ${timestamp}`);

            try {
                await ses.send(new SendEmailCommand({
                    Source: FROM_EMAIL,
                    Destination: { ToAddresses: [ADMIN_EMAIL] },
                    Message: {
                        Subject: { Data: subjectLabel },
                        Body: { Text: { Data: emailLines.join('\n') } },
                    },
                }));
            } catch (sesError) {
                console.error('SES notification failed:', sesError);
            }
        }

        return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: JSON.stringify({ message: 'Application received', id: applicationId }),
        };

    } catch (err) {
        console.error('Error processing application:', err);
        return {
            statusCode: 500,
            headers: CORS_HEADERS,
            body: JSON.stringify({ error: 'Internal server error' }),
        };
    }
};
