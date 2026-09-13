class ContextManager {
  ctx: Context | null = null;
  UiCtx: UIContext | null = null;

  getCtx() {
    return this.ctx;
  }

  getUiCtx() {
    return this.UiCtx;
  }
}

export const contextManager = new ContextManager();