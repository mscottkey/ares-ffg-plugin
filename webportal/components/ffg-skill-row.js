import Component from '@glimmer/component';
import { action } from '@ember/object';
import { set } from '@ember/object';

export default class FfgSkillRowComponent extends Component {
  get maxRating() {
    // from @maxRating or default
    return this.args.maxRating ?? 2;
  }

  @action
  increase() {
    let s = this.args.skill;
    if (!s) return;

    let current = s.rating || 0;
    if (current >= this.maxRating) return;

    set(s, 'rating', current + 1);

    if (this.args.updated) {
      this.args.updated();
    }
  }

  @action
  decrease() {
    let s = this.args.skill;
    if (!s) return;

    let current = s.rating || 0;
    if (current <= 0) return;

    set(s, 'rating', current - 1);

    if (this.args.updated) {
      this.args.updated();
    }
  }
}
