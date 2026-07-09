declare module "node-ews" {
  interface EWSConfig {
    username: string;
    password: string;
    host: string;
    auth?: "ntlm" | "basic" | "bearer";
  }
  class EWS {
    constructor(config: EWSConfig);
    run(action: string, args: Record<string, unknown>): Promise<unknown>;
  }
  export = EWS;
}
