"use client";
import { useEffect } from "react";
export default function GlobalError({error,reset}:{error:Error&{digest?:string};reset:()=>void}) { useEffect(()=>{console.error("Application rendering error",{digest:error.digest});},[error]); return <html lang="en"><body><main style={{maxWidth:720,margin:"10vh auto",padding:24,fontFamily:"Arial,sans-serif"}}><p>Something went wrong.</p><button type="button" onClick={()=>reset()}>Try again</button></main></body></html>; }
