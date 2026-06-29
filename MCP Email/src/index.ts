import "dotenv/config";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { emailClient } from "./emailClient.js";
import {
  searchEmailsShape,
  readEmailShape,
  sendEmailShape,
  getEmailImageShape,
  handleSearchEmails,
  handleReadEmail,
  handleSendEmail,
  handleGetEmailImage,
} from "./tools.js";

const server = new McpServer({
  name: "mcp-email-connector",
  version: "1.0.0",
});

server.registerTool(
  "search_emails",
  {
    title: "Search Emails",
    description:
      "Search the INBOX for incoming emails. Returns lightweight summaries " +
      "(Message ID, Subject, From, Date). Supports a keyword query, a result " +
      "limit, and an unread-only filter.",
    inputSchema: searchEmailsShape,
  },
  handleSearchEmails
);

server.registerTool(
  "read_email",
  {
    title: "Read Email",
    description:
      "Fetch the full detail of a single email by its Message ID. The body is " +
      "returned as clean plain text / Markdown (HTML is converted) to save tokens. " +
      "Includes an 'attachments' list (filename/type/size only) — use get_email_image " +
      "to actually view an image attachment.",
    inputSchema: readEmailShape,
  },
  handleReadEmail
);

server.registerTool(
  "get_email_image",
  {
    title: "Get Email Image",
    description:
      "Fetch one image attachment from an email (by filename, as listed in " +
      "read_email's attachments array) and return it as a viewable image. Use this " +
      "when a user describes a problem via a screenshot attached to an email.",
    inputSchema: getEmailImageShape,
  },
  handleGetEmailImage
);

server.registerTool(
  "send_email",
  {
    title: "Send Email",
    description: "Send a new email or reply. Body is plain text / markdown.",
    inputSchema: sendEmailShape,
  },
  handleSendEmail
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr is safe for logging (stdout is reserved for the MCP protocol).
  console.error("[mcp-email-connector] running on stdio");
}

async function shutdown() {
  await emailClient.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

main().catch((err) => {
  console.error("[mcp-email-connector] fatal:", err);
  process.exit(1);
});
