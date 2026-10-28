/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef WORDPREDICTOR_H
#define WORDPREDICTOR_H

#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

/*
 * WordPredictor: the suggestions of WearKeyboard, as Gboard's strip shows
 * them: completions of the word being typed and, when it is no word,
 * corrections of it (one or two letters off), the likeliest first and in
 * the case it was typed in.
 *
 * The words come from /usr/share/asteroid-keyboard/en_GB.words (the image's
 * asteroid-keyboard-words: SCOWL's British English lists, "word<TAB>rank",
 * rank = the SCOWL size the word first appears in, 10 for the commonest).
 * They are read once per process, in a worker thread, when the first
 * WordPredictor is made; until then (or without the file) available is
 * false and suggest() returns nothing. ASTEROID_KEYBOARD_WORDS names
 * another list (tests). A suggestion takes well under a
 * millisecond for a completion and a few for a correction on the watch.
 */
class WordPredictor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit WordPredictor(QObject *parent = nullptr);

    bool available() const;

    /* Up to count words for the word being typed, the likeliest first */
    Q_INVOKABLE QStringList suggest(const QString &word, int count = 3) const;
    /* The word is in the list (any case) */
    Q_INVOKABLE bool isWord(const QString &word) const;

    /* For tests: read this list instead (before the first WordPredictor) */
    static void setWordsFile(const QString &path);

signals:
    void availableChanged();
};

#endif // WORDPREDICTOR_H
