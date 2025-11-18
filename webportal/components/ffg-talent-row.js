import Component from '@glimmer/component';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';

export default class FfgTalentRowComponent extends Component {
  @service gameApi;

  get rank() {
    return this.args.talent.rank || 0;
  }

  get maxRank() {
    // If talent config is provided in cgInfo, it may have max_rank, otherwise
    // default to 5 for ranked talents.
    const config = (this.args.cgInfo && this.args.cgInfo.talents) ? this.args.cgInfo.talents.find(t => t['name'] === this.args.talent.name) : null;
    return (config && config['max_rank']) ? config['max_rank'] : 5;
  }

  @action
  async increase() {
    const name = this.args.talent.name;
    if (!name) return;

    // Local pre-checks can be performed before calling server.
    if (this.args.talent.rank && this.args.talent.rank >= this.maxRank) return;
    if (this.args.addDisabled) return;

    // Prefer central server command via parent-provided callback
    if (this.args.addTalent) {
      await this.args.addTalent(name);
      return;
    }

    // Fallback: try using gameApi (best-effort; signature depends on app)
    if (this.gameApi && this.gameApi.sendCommand) {
      this.gameApi.sendCommand(`talent add ${name}`);
    } else if (this.gameApi && this.gameApi.request) {
      try {
        await this.gameApi.request(`/cmd/talent/add`, { name: name });
      } catch (e) {
        // no-op; parent `@updated` will revalidate
      }
    }

    if (this.args.updated) this.args.updated();
  }

  @action
  async decrease() {
    const name = this.args.talent.name;
    if (!name) return;

    if (this.args.removeDisabled) return;

    if (this.args.removeTalent) {
      await this.args.removeTalent(name);
      return;
    }

    // Fallback to gameApi
    if (this.gameApi && this.gameApi.sendCommand) {
      this.gameApi.sendCommand(`talent remove ${name}`);
    } else if (this.gameApi && this.gameApi.request) {
      try {
        await this.gameApi.request(`/cmd/talent/remove`, { name: name });
      } catch (e) {
      }
    }

    if (this.args.updated) this.args.updated();
  }
}
