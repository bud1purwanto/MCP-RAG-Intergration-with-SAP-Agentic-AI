import { z } from "zod";
import { emailClient } from "./emailClient.js";

/**
 * Tool input schemas (Zod). The raw shapes are exported so they can be passed
 * directly to the MCP server's registerTool() inputSchema field.
 */

export const searchEmailsShape = {
  query: z
    .string()
    .optional()
    .describe('Optional keyword to match in subject/body, e.g. "error", "issue".'),
  maxResults: z
    .number()
    .int()
    .positive()
    .default(5)
    .describe("Maximum number of emails to return (default 5)."),
  unreadOnly: z
    .boolean()
    .default(false)
    .describe("If true, only return unread (unseen) emails."),
};

export const readEmailShape = {
  messageId: z
    .string()
    .describe('The Message ID returned by search_emails (RFC Message-ID or "uid:<n>").'),
};

export const sendEmailShape = {
  to: z.string().describe("Recipient email address."),
  subject: z.string().describe("Email subject line."),
  body: z.string().describe("Email body in plain text / markdown."),
};

export const getEmailImageShape = {
  messageId: z
    .string()
    .describe('The Message ID of the email (RFC Message-ID or "uid:<n>").'),
  filename: z
    .string()
    .describe(
      'Attachment filename, exactly as listed in read_email\'s "attachments" array.'
    ),
};

const searchEmailsSchema = z.object(searchEmailsShape);
const readEmailSchema = z.object(readEmailShape);
const sendEmailSchema = z.object(sendEmailShape);
const getEmailImageSchema = z.object(getEmailImageShape);

type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; data: string; mimeType: string };
type TextResult = { content: ContentBlock[]; isError?: boolean };

function ok(data: unknown): TextResult {
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}

function fail(err: unknown): TextResult {
  const message = err instanceof Error ? err.message : String(err);
  return { content: [{ type: "text", text: `Error: ${message}` }], isError: true };
}

// ---- Handlers -------------------------------------------------------------

export async function handleSearchEmails(args: unknown): Promise<TextResult> {
  try {
    const { query, maxResults, unreadOnly } = searchEmailsSchema.parse(args);
    const results = await emailClient.searchEmails({ query, maxResults, unreadOnly });
    return ok({ count: results.length, emails: results });
  } catch (err) {
    return fail(err);
  }
}

export async function handleReadEmail(args: unknown): Promise<TextResult> {
  try {
    const { messageId } = readEmailSchema.parse(args);
    const detail = await emailClient.readEmail(messageId);
    return ok(detail);
  } catch (err) {
    return fail(err);
  }
}

export async function handleGetEmailImage(args: unknown): Promise<TextResult> {
  try {
    const { messageId, filename } = getEmailImageSchema.parse(args);
    const image = await emailClient.getImageAttachment(messageId, filename);
    return {
      content: [
        { type: "text", text: `Image "${image.filename}" (${image.mimeType}):` },
        { type: "image", data: image.base64, mimeType: image.mimeType },
      ],
    };
  } catch (err) {
    return fail(err);
  }
}

export async function handleSendEmail(args: unknown): Promise<TextResult> {
  try {
    const { to, subject, body } = sendEmailSchema.parse(args);
    const messageId = await emailClient.sendEmail({ to, subject, body });
    return ok({ status: "sent", messageId, to, subject });
  } catch (err) {
    return fail(err);
  }
}
