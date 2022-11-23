/**
 * @name Alert suppression
 * @description Generates information about alert suppressions.
 * @kind alert-suppression
 * @id py/alert-suppression
 */

import python

/**
 * An alert suppression comment.
 */
abstract class SuppressionComment extends Comment {
  /** Gets the scope of this suppression. */
  abstract SuppressionScope getScope();

  /** Gets the suppression annotation in this comment. */
  abstract string getAnnotation();

  /**
   * Holds if this comment applies to the range from column `startcolumn` of line `startline`
   * to column `endcolumn` of line `endline` in file `filepath`.
   */
  abstract predicate covers(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  );
}

/**
 * An alert comment that applies to a single line
 */
abstract class LineSuppressionComment extends SuppressionComment {
  LineSuppressionComment() {
    exists(string filepath, int l |
      this.getLocation().hasLocationInfo(filepath, l, _, _, _) and
      any(AstNode a).getLocation().hasLocationInfo(filepath, l, _, _, _)
    )
  }

  /** Gets the scope of this suppression. */
  override SuppressionScope getScope() { result = this }

  override predicate covers(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  ) {
    this.getLocation().hasLocationInfo(filepath, startline, _, endline, endcolumn) and
    startcolumn = 1
  }
}

/**
 * An codeql suppression comment.
 */
class CodeQLSuppressionComment extends LineSuppressionComment {
  string annotation;

  CodeQLSuppressionComment() {
    exists(string all | all = this.getContents() |
      // match `codeql[...]` anywhere in the comment
      annotation =
        all.regexpFind("(?i)\\bcodeql\\s*\\[[^\\]]*\\]", _, _).regexpReplaceAll("^codeql", "lgtm")
      or
      // match `codeql` at the start of the comment and after semicolon
      annotation =
        all.regexpFind("(?i)(?<=^|;)\\s*codeql(?!\\B|\\s*\\[)", _, _)
            .trim()
            .regexpReplaceAll("^codeql", "lgtm")
    )
  }

  /** Gets the suppression annotation in this comment. */
  override string getAnnotation() { result = annotation }
}

/**
 * A noqa suppression comment. Both pylint and pyflakes respect this, so codeql ought to too.
 */
class NoqaSuppressionComment extends LineSuppressionComment {
  NoqaSuppressionComment() { this.getContents().toLowerCase().regexpMatch("\\s*noqa\\s*([^:].*)?") }

  override string getAnnotation() { result = "codeql" }
}

/**
 * The scope of an alert suppression comment.
 */
class SuppressionScope extends @py_comment {
  SuppressionScope() { this instanceof SuppressionComment }

  /**
   * Holds if this element is at the specified location.
   * The location spans column `startcolumn` of line `startline` to
   * column `endcolumn` of line `endline` in file `filepath`.
   * For more information, see
   * [Locations](https://codeql.github.com/docs/writing-codeql-queries/providing-locations-in-codeql-queries/).
   */
  predicate hasLocationInfo(
    string filepath, int startline, int startcolumn, int endline, int endcolumn
  ) {
    this.(SuppressionComment).covers(filepath, startline, startcolumn, endline, endcolumn)
  }

  /** Gets a textual representation of this element. */
  string toString() { result = "suppression range" }
}

from SuppressionComment c
select c, // suppression comment
  c.getContents(), // text of suppression comment (excluding delimiters)
  c.getAnnotation(), // text of suppression annotation
  c.getScope() // scope of suppression
