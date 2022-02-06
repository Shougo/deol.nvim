import {
  BaseSource,
  Candidate,
  Context,
  DdcOptions,
  SourceOptions,
} from "https://deno.land/x/ddc_vim@v0.18.0/types.ts#^";
import { Denops } from "https://deno.land/x/ddc_vim@v0.18.0/deps.ts#^";

type Params = Record<string, never>;

export class Source extends BaseSource<Params> {
  async gatherCandidates(args: {
    denops: Denops;
    context: Context;
    options: DdcOptions;
    sourceOptions: SourceOptions;
    completeStr: string;
  }): Promise<Candidate[]> {
    const histories = await args.denops.call(
      "deol#_get_histories",
    ) as string[];
    const input = await args.denops.call("deol#get_input") as string;
    const inputLength = input.length - args.completeStr.length;
    const filterInput = input.substring(0, inputLength);
    return histories.filter((word) => word.startsWith(filterInput))
      .map((word) => ({ word: word.substring(inputLength) }));
  }

  params(): Params {
    return {};
  }
}
