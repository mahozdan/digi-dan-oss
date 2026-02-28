// lambda/apply/index.mjs
// Handles community application form submissions
// Stores in DynamoDB + optionally sends notification via SES

import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { randomUUID } from 'crypto';

const dynamo = new DynamoDBClient({ region: 'il-central-1' });
const ses = new SESClient({ region: 'il-central-1' });

const TABLE_NAME = process.env.TABLE_NAME || 'community-applications';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || '';
const FROM_EMAIL = process.env.FROM_EMAIL || '';

export const handler = async (event) => {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (event.requestContext?.http?.method === 'OPTIONS') {
        return { statusCode: 200, headers, body: '' };
    }

    try {
        const body = JSON.parse(event.body);

        // Basic validation
        if (!body.name || !body.email || !body.github || !body.project_idea) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Missing required fields: name, email, github, project_idea' }),
            };
        }

        // Simple email validation
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email)) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Invalid email address' }),
            };
        }

        const applicationId = randomUUID();
        const timestamp = new Date().toISOString();

        // Store in DynamoDB
        await dynamo.send(new PutItemCommand({
            TableName: TABLE_NAME,
            Item: {
                id: { S: applicationId },
                email: { S: body.email },
                name: { S: body.name },
                github: { S: body.github },
                language: { S: body.language || 'not specified' },
                aws_experience: { S: body.aws_experience || 'not specified' },
                project_idea: { S: body.project_idea },
                organization: { S: body.organization || '' },
                status: { S: 'pending' },
                submitted_at: { S: timestamp },
            },
            ConditionExpression: 'attribute_not_exists(id)',
        }));

        // Send notification email to admin (if configured)
        if (ADMIN_EMAIL && FROM_EMAIL) {
            try {
                await ses.send(new SendEmailCommand({
                    Source: FROM_EMAIL,
                    Destination: { ToAddresses: [ADMIN_EMAIL] },
                    Message: {
                        Subject: { Data: `New community application: ${body.name} (@${body.github})` },
                        Body: {
                            Text: {
                                Data: [
                                    `New application received`,
                                    ``,
                                    `Name: ${body.name}`,
                                    `Email: ${body.email}`,
                                    `GitHub: https://github.com/${body.github}`,
                                    `Language: ${body.language || 'not specified'}`,
                                    `AWS Experience: ${body.aws_experience || 'not specified'}`,
                                    `Organization: ${body.organization || 'none'}`,
                                    ``,
                                    `Project Idea:`,
                                    body.project_idea,
                                    ``,
                                    `Application ID: ${applicationId}`,
                                    `Submitted: ${timestamp}`,
                                ].join('\n'),
                            },
                        },
                    },
                }));
            } catch (sesError) {
                // Don't fail the application if email fails
                console.error('SES notification failed:', sesError);
            }
        }

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                message: 'Application received',
                id: applicationId,
            }),
        };

    } catch (err) {
        console.error('Error processing application:', err);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: 'Internal server error' }),
        };
    }
};
