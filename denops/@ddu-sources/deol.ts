import {
  BaseSource,
  Item,
} from "https://deno.land/x/ddu_vim@v0.7.1/types.ts#^";
import { Denops, fn } from "https://deno.land/x/ddu_vim@v0.7.1/deps.ts#^";
import { ActionData } from "../@ddu-kinds/deol.ts";

type Params = {
  command: string;
};

export class Source extends BaseSource<Params> {
  kind = "deol";

  gather(args: {
    denops: Denops;
    sourceParams: Params;
  }): ReadableStream<Item<ActionData>[]> {
    return new ReadableStream({
      async start(controller) {
        const items = Promise.all(
          [...Array(await fn.tabpagenr(args.denops, "$"))].map(
            async (_, i) => {
              const tabNr = i + 1;
              const deol =
                (await fn.gettabvar(args.denops, tabNr, "deol", null)) as {
                  cwd: string;
                };
              return {
                word: deol ? `${tabNr}: ${deol.cwd}` : `${tabNr}: [new]`,
                action: {
                  command: args.sourceParams.command,
                  tabNr: tabNr,
                  existsDeol: Boolean(deol),
                },
              };
            },
          ),
        );

        controller.enqueue(
          await items,
        );

        controller.close();
      },
    });
  }

  params(): Params {
    return {
      command: "",
    };
  }
}
